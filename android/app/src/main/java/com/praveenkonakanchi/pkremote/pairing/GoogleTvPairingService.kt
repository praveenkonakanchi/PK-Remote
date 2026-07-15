package com.praveenkonakanchi.pkremote.pairing

import android.util.Log
import com.praveenkonakanchi.pkremote.model.RemoteDevice
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.net.InetSocketAddress
import java.net.Socket
import java.security.MessageDigest
import java.security.Principal
import java.security.PrivateKey
import java.security.SecureRandom
import java.security.cert.X509Certificate
import java.security.interfaces.RSAPublicKey
import java.util.concurrent.ConcurrentHashMap
import javax.net.ssl.KeyManager
import javax.net.ssl.KeyManagerFactory
import javax.net.ssl.SSLContext
import javax.net.ssl.SSLEngine
import javax.net.ssl.SSLException
import javax.net.ssl.SSLSocket
import javax.net.ssl.TrustManager
import javax.net.ssl.X509ExtendedKeyManager
import javax.net.ssl.X509TrustManager

internal class GoogleTvPairingService(
    private val identityStore: PairingIdentityStore,
    private val credentialStore: PairingCredentialStore,
) : DevicePairingService {
    private val sessions = ConcurrentHashMap<String, PairingSession>()

    override suspend fun requestPairingCode(device: RemoteDevice) = withContext(Dispatchers.IO) {
        val host = device.endpointHost
            ?: throw PairingException("Refresh Devices so the TV pairing service can be resolved.")
        val identity = identityStore.loadOrCreate()
        val session = try {
            PairingSession(host, identity, identityStore.keyStore())
        } catch (error: Throwable) {
            throw error.asPairingException()
        }
        sessions.remove(device.id)?.close()
        sessions[device.id] = session
        try {
            session.start("PK Remote")
        } catch (error: Throwable) {
            sessions.remove(device.id, session)
            session.close()
            throw error.asPairingException()
        }
    }

    override suspend fun pair(device: RemoteDevice, code: String) = withContext(Dispatchers.IO) {
        val session = sessions.remove(device.id)
            ?: throw PairingException("The pairing session expired. Start pairing again.")
        try {
            val tvFingerprint = session.finish(code)
            credentialStore.save(
                device.id,
                PairingCredential(tvFingerprint, session.clientCertificateFingerprint),
            )
        } catch (error: Throwable) {
            throw error.asPairingException()
        } finally {
            session.close()
        }
    }

    override suspend fun cancel(device: RemoteDevice) = withContext(Dispatchers.IO) {
        sessions.remove(device.id)?.close()
        Unit
    }

    override fun close() {
        sessions.values.forEach(PairingSession::close)
        sessions.clear()
    }
}

private class PairingSession(
    host: String,
    private val identity: PairingIdentity,
    keyStore: java.security.KeyStore,
) : AutoCloseable {
    private val trustManager = PairingTrustManager()
    private val socket: SSLSocket

    val clientCertificateFingerprint: ByteArray get() = identity.certificateFingerprint

    init {
        val keyManagerFactory = KeyManagerFactory.getInstance(KeyManagerFactory.getDefaultAlgorithm()).apply {
            init(keyStore, null)
        }
        val delegate = keyManagerFactory.keyManagers.filterIsInstance<X509ExtendedKeyManager>().firstOrNull()
            ?: throw PairingException("Could not configure the Android pairing identity.")
        val sslContext = SSLContext.getInstance("TLS").apply {
            init(
                arrayOf<KeyManager>(AliasKeyManager(delegate, identity.alias)),
                arrayOf<TrustManager>(trustManager),
                SecureRandom(),
            )
        }
        socket = sslContext.socketFactory.createSocket() as SSLSocket
        socket.soTimeout = ReadTimeoutMillis
        socket.enabledProtocols = socket.supportedProtocols.filter { it == "TLSv1.2" || it == "TLSv1.3" }.toTypedArray()
        socket.connect(InetSocketAddress(host, PairingPort), ConnectTimeoutMillis)
    }

    fun start(clientName: String) {
        Log.d(LogTag, "Starting secure pairing session on port $PairingPort")
        socket.startHandshake()
        send(PairingProtocolCodec.pairingRequest(clientName))
        repeat(MaximumHandshakeMessages) {
            when (receiveKind()) {
                PairingMessageKind.PairingRequestAcknowledgement -> send(PairingProtocolCodec.options())
                PairingMessageKind.Options -> send(PairingProtocolCodec.configuration())
                PairingMessageKind.ConfigurationAcknowledgement -> return
                else -> throw PairingException("The TV returned an unexpected pairing response.")
            }
        }
        throw PairingException("The TV pairing handshake did not complete.")
    }

    fun finish(code: String): ByteArray {
        val serverCertificate = trustManager.serverCertificate
            ?: throw PairingException("The TV pairing certificate was not available.")
        val clientPublicKey = identity.certificate.publicKey as? RSAPublicKey
            ?: throw PairingException("The Android pairing identity is not an RSA key.")
        val serverPublicKey = serverCertificate.publicKey as? RSAPublicKey
            ?: throw PairingException("The TV pairing identity is not an RSA key.")
        send(PairingProtocolCodec.secret(PairingSecret.make(code, clientPublicKey, serverPublicKey)))
        if (receiveKind() != PairingMessageKind.SecretAcknowledgement) {
            throw PairingException("The pairing code was not accepted. Check the code on your TV and try again.")
        }
        return MessageDigest.getInstance("SHA-256").digest(serverCertificate.encoded)
    }

    override fun close() {
        runCatching { socket.close() }
    }

    private fun send(payload: ByteArray) = PairingProtocolCodec.writeFrame(socket.outputStream, payload)
    private fun receiveKind(): PairingMessageKind = PairingProtocolCodec.decodeKind(
        PairingProtocolCodec.readFrame(socket.inputStream),
    )

    private companion object {
        const val PairingPort = 6467
        const val ConnectTimeoutMillis = 15_000
        const val ReadTimeoutMillis = 15_000
        const val MaximumHandshakeMessages = 8
        const val LogTag = "PKRemotePairing"
    }
}

private class PairingTrustManager : X509TrustManager {
    @Volatile
    var serverCertificate: X509Certificate? = null
        private set

    override fun checkServerTrusted(chain: Array<out X509Certificate>?, authType: String?) {
        serverCertificate = chain?.firstOrNull()
            ?: throw PairingException("The TV did not present a pairing certificate.")
    }

    override fun checkClientTrusted(chain: Array<out X509Certificate>?, authType: String?) =
        throw PairingException("Unexpected client certificate validation request.")

    override fun getAcceptedIssuers(): Array<X509Certificate> = emptyArray()
}

private class AliasKeyManager(
    private val delegate: X509ExtendedKeyManager,
    private val alias: String,
) : X509ExtendedKeyManager() {
    override fun chooseClientAlias(keyType: Array<out String>?, issuers: Array<out Principal>?, socket: Socket?): String = alias
    override fun chooseEngineClientAlias(keyType: Array<out String>?, issuers: Array<out Principal>?, engine: SSLEngine?): String = alias
    override fun getClientAliases(keyType: String?, issuers: Array<out Principal>?): Array<String> = arrayOf(alias)
    override fun getCertificateChain(requestedAlias: String?): Array<X509Certificate>? = delegate.getCertificateChain(requestedAlias)
    override fun getPrivateKey(requestedAlias: String?): PrivateKey? = delegate.getPrivateKey(requestedAlias)
    override fun chooseServerAlias(keyType: String?, issuers: Array<out Principal>?, socket: Socket?): String? = null
    override fun getServerAliases(keyType: String?, issuers: Array<out Principal>?): Array<String>? = null
    override fun chooseEngineServerAlias(keyType: String?, issuers: Array<out Principal>?, engine: SSLEngine?): String? = null
}

private fun Throwable.asPairingException(): PairingException = when (this) {
    is PairingException -> this
    is PairingProtocolException -> PairingException(message ?: "The TV returned invalid pairing data.", this)
    is SSLException -> PairingException("Could not establish a secure pairing connection. Try Pair Again.", this)
    else -> PairingException("Could not complete secure pairing: ${message ?: javaClass.simpleName}", this)
}
