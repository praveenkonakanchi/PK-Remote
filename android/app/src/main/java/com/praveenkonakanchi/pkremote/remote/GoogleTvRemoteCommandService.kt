package com.praveenkonakanchi.pkremote.remote

import android.util.Log
import com.praveenkonakanchi.pkremote.model.RemoteCommand
import com.praveenkonakanchi.pkremote.model.RemoteDevice
import com.praveenkonakanchi.pkremote.pairing.PairingCredentialStore
import com.praveenkonakanchi.pkremote.pairing.PairingIdentity
import com.praveenkonakanchi.pkremote.pairing.PairingIdentityStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import java.net.InetSocketAddress
import java.net.Socket
import java.security.MessageDigest
import java.security.Principal
import java.security.PrivateKey
import java.security.SecureRandom
import java.security.cert.CertificateException
import java.security.cert.X509Certificate
import java.util.concurrent.ConcurrentHashMap
import javax.net.ssl.KeyManager
import javax.net.ssl.KeyManagerFactory
import javax.net.ssl.SSLContext
import javax.net.ssl.SSLEngine
import javax.net.ssl.SSLHandshakeException
import javax.net.ssl.SSLSocket
import javax.net.ssl.TrustManager
import javax.net.ssl.X509ExtendedKeyManager
import javax.net.ssl.X509TrustManager

internal class GoogleTvRemoteCommandService(
    private val identityStore: PairingIdentityStore,
    private val credentialStore: PairingCredentialStore,
) : RemoteCommandService {
    private val sessions = ConcurrentHashMap<String, RemoteSession>()
    private val mutex = Mutex()

    override suspend fun send(command: RemoteCommand, device: RemoteDevice) = withContext(Dispatchers.IO) {
        mutex.withLock {
            val session = session(device)
            try {
                session.send(command)
            } catch (error: Throwable) {
                sessions.remove(device.id, session)
                session.close()
                val transportError = error.asTransportException(session)
                if (!command.retriesAfterFailure || transportError.invalidatesPairing) throw transportError
                val replacement = makeSession(device)
                sessions[device.id] = replacement
                replacement.send(command)
            }
        }
    }

    override suspend fun stopSession(device: RemoteDevice) = withContext(Dispatchers.IO) {
        sessions.remove(device.id)?.close()
        Unit
    }

    override fun close() {
        sessions.values.forEach(RemoteSession::close)
        sessions.clear()
    }

    private fun session(device: RemoteDevice): RemoteSession {
        sessions[device.id]?.takeIf { it.isUsable }?.let { return it }
        sessions.remove(device.id)?.close()
        return makeSession(device).also { sessions[device.id] = it }
    }

    private fun makeSession(device: RemoteDevice): RemoteSession {
        val host = device.endpointHost ?: throw RemoteTransportException.EndpointUnavailable
        val credential = credentialStore.credential(device.id) ?: throw RemoteTransportException.NotPaired
        val identity = identityStore.loadOrCreate()
        return RemoteSession(host, identity, identityStore.keyStore(), credential.tvCertificateFingerprint).apply {
            try {
                start()
            } catch (error: Throwable) {
                close()
                throw error.asTransportException(this)
            }
        }
    }
}

private class RemoteSession(
    host: String,
    identity: PairingIdentity,
    keyStore: java.security.KeyStore,
    expectedTvFingerprint: ByteArray,
) : AutoCloseable {
    private val trustManager = PinnedTvTrustManager(expectedTvFingerprint)
    private val socket: SSLSocket
    private val outputLock = Any()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var monitorJob: Job? = null
    @Volatile private var usable = false
    @Volatile private var imeCounter = 0
    @Volatile private var fieldCounter = 0

    val isUsable: Boolean get() = usable && !socket.isClosed
    val receivedTvCertificate: Boolean get() = trustManager.receivedCertificate
    val tvCertificateMatches: Boolean get() = trustManager.matches

    init {
        val keyManagerFactory = KeyManagerFactory.getInstance(KeyManagerFactory.getDefaultAlgorithm()).apply {
            init(keyStore, null)
        }
        val delegate = keyManagerFactory.keyManagers.filterIsInstance<X509ExtendedKeyManager>().firstOrNull()
            ?: throw RemoteTransportException.ConnectionFailed("Could not load the Android client identity.")
        val sslContext = SSLContext.getInstance("TLS").apply {
            init(
                arrayOf<KeyManager>(RemoteAliasKeyManager(delegate, identity.alias)),
                arrayOf<TrustManager>(trustManager),
                SecureRandom(),
            )
        }
        socket = sslContext.socketFactory.createSocket() as SSLSocket
        socket.useClientMode = true
        socket.tcpNoDelay = true
        socket.keepAlive = true
        socket.soTimeout = HandshakeReadTimeoutMillis
        socket.enabledProtocols = socket.supportedProtocols.filter { it == "TLSv1.2" || it == "TLSv1.3" }.toTypedArray()
        socket.connect(InetSocketAddress(host, RemotePort), ConnectTimeoutMillis)
    }

    fun start() {
        Log.d(LogTag, "Connecting to remote service on port $RemotePort")
        socket.startHandshake()
        while (true) {
            when (val message = receive()) {
                RemoteProtocolMessage.Configure -> {
                    sendPayload(RemoteProtocolCodec.configure())
                    usable = true
                    socket.soTimeout = 0
                    monitorJob = scope.launch { monitor() }
                    Log.d(LogTag, "Remote session ready")
                    return
                }
                is RemoteProtocolMessage.SetActive -> sendPayload(RemoteProtocolCodec.setActive(message.value))
                is RemoteProtocolMessage.Ping -> sendPayload(RemoteProtocolCodec.pingResponse(message.value))
                is RemoteProtocolMessage.ImeBatchEdit -> updateIme(message)
                else -> Unit
            }
        }
    }

    suspend fun send(command: RemoteCommand) {
        Log.d(LogTag, "Sending ${command.accessibilityLabel}")
        when (command) {
            is RemoteCommand.EnterText -> sendPayload(RemoteProtocolCodec.text(command.value, imeCounter, fieldCounter))
            is RemoteCommand.LaunchApp -> sendPayload(RemoteProtocolCodec.appLink(command.launchIdentifier))
            RemoteCommand.GoogleTvQuickSettings -> {
                sendPayload(RemoteProtocolCodec.key(command, RemoteKeyDirection.StartLong))
                try {
                    delay(650)
                } finally {
                    sendPayload(RemoteProtocolCodec.key(command, RemoteKeyDirection.EndLong))
                }
            }
            else -> sendPayload(RemoteProtocolCodec.key(command))
        }
    }

    override fun close() {
        usable = false
        monitorJob?.cancel()
        scope.coroutineContext[Job]?.cancel()
        runCatching { socket.close() }
    }

    private suspend fun monitor() {
        try {
            while (scope.isActive && !socket.isClosed) {
                when (val message = receive()) {
                    is RemoteProtocolMessage.SetActive -> sendPayload(RemoteProtocolCodec.setActive(message.value))
                    is RemoteProtocolMessage.Ping -> sendPayload(RemoteProtocolCodec.pingResponse(message.value))
                    is RemoteProtocolMessage.ImeBatchEdit -> updateIme(message)
                    is RemoteProtocolMessage.RemoteError -> Log.d(
                        LogTag,
                        "TV response for field ${message.originalField}: ${if (message.isError) "rejected" else "accepted"}",
                    )
                    else -> Unit
                }
            }
        } catch (error: Throwable) {
            if (!socket.isClosed) Log.w(LogTag, "Remote receive loop stopped", error)
            usable = false
            runCatching { socket.close() }
        }
    }

    private fun updateIme(message: RemoteProtocolMessage.ImeBatchEdit) {
        imeCounter = message.imeCounter
        fieldCounter = message.fieldCounter
    }

    private fun sendPayload(payload: ByteArray) = synchronized(outputLock) {
        RemoteProtocolCodec.writeFrame(socket.outputStream, payload)
    }

    private fun receive(): RemoteProtocolMessage = RemoteProtocolCodec.decode(
        RemoteProtocolCodec.readFrame(socket.inputStream),
    )

    private companion object {
        const val RemotePort = 6466
        const val ConnectTimeoutMillis = 15_000
        const val HandshakeReadTimeoutMillis = 15_000
        const val LogTag = "PKRemoteTransport"
    }
}

private class PinnedTvTrustManager(private val expectedFingerprint: ByteArray) : X509TrustManager {
    @Volatile var receivedCertificate = false
        private set
    @Volatile var matches = false
        private set

    override fun checkServerTrusted(chain: Array<out X509Certificate>?, authType: String?) {
        val leaf = chain?.firstOrNull() ?: throw CertificateException("The TV did not present a certificate.")
        receivedCertificate = true
        matches = MessageDigest.isEqual(
            MessageDigest.getInstance("SHA-256").digest(leaf.encoded),
            expectedFingerprint,
        )
        if (!matches) throw CertificateException("The TV certificate changed.")
    }

    override fun checkClientTrusted(chain: Array<out X509Certificate>?, authType: String?) =
        throw CertificateException("Unexpected client trust request.")
    override fun getAcceptedIssuers(): Array<X509Certificate> = emptyArray()
}

private class RemoteAliasKeyManager(
    private val delegate: X509ExtendedKeyManager,
    private val alias: String,
) : X509ExtendedKeyManager() {
    override fun chooseClientAlias(keyType: Array<out String>?, issuers: Array<out Principal>?, socket: Socket?) = alias
    override fun chooseEngineClientAlias(keyType: Array<out String>?, issuers: Array<out Principal>?, engine: SSLEngine?) = alias
    override fun getClientAliases(keyType: String?, issuers: Array<out Principal>?) = arrayOf(alias)
    override fun getCertificateChain(requestedAlias: String?) = delegate.getCertificateChain(requestedAlias)
    override fun getPrivateKey(requestedAlias: String?): PrivateKey? = delegate.getPrivateKey(requestedAlias)
    override fun chooseServerAlias(keyType: String?, issuers: Array<out Principal>?, socket: Socket?): String? = null
    override fun getServerAliases(keyType: String?, issuers: Array<out Principal>?): Array<String>? = null
    override fun chooseEngineServerAlias(keyType: String?, issuers: Array<out Principal>?, engine: SSLEngine?): String? = null
}

private val RemoteCommand.retriesAfterFailure: Boolean
    get() = this !is RemoteCommand.LaunchApp && this != RemoteCommand.GoogleTvQuickSettings

private fun Throwable.asTransportException(session: RemoteSession): RemoteTransportException = when {
    this is RemoteTransportException -> this
    session.receivedTvCertificate && !session.tvCertificateMatches -> RemoteTransportException.CertificateChanged
    this is SSLHandshakeException && session.tvCertificateMatches -> RemoteTransportException.PairingRejected
    this is RemoteProtocolException -> RemoteTransportException.ConnectionFailed(message ?: "Invalid remote response.")
    else -> RemoteTransportException.ConnectionFailed(message ?: javaClass.simpleName)
}
