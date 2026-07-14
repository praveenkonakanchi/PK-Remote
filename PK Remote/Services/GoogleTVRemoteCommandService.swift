import CryptoKit
import Foundation
import Network
import OSLog
import Security

nonisolated enum RemoteCommandTransportError: LocalizedError {
    case deviceEndpointUnavailable
    case notPaired
    case connectionFailed(String)
    case certificateChanged
    case unsupportedCommand
    case protocolFailure

    var errorDescription: String? {
        switch self {
        case .deviceEndpointUnavailable:
            "Refresh Devices before using the remote."
        case .notPaired:
            "Pair this TV before sending remote commands."
        case .connectionFailed(let message):
            "Could not connect to the TV remote service: \(message)"
        case .certificateChanged:
            "The TV identity changed. Pair the TV again before reconnecting."
        case .unsupportedCommand:
            "This remote command is not supported."
        case .protocolFailure:
            "The TV returned an unexpected remote response."
        }
    }
}

actor GoogleTVRemoteCommandService: RemoteCommandHandling {
    private nonisolated static let remotePort = NWEndpoint.Port(rawValue: 6466)!
    private let identityStore: PairingIdentityStore
    private let credentialStore: PairingCredentialStore
    private var sessions: [RemoteDevice.ID: GoogleTVRemoteSession] = [:]

    init(
        identityStore: PairingIdentityStore = PairingIdentityStore(),
        credentialStore: PairingCredentialStore = PairingCredentialStore()
    ) {
        self.identityStore = identityStore
        self.credentialStore = credentialStore
    }

    func send(_ command: RemoteCommand, to device: RemoteDevice) async throws {
        let session = try await session(for: device)
        do {
            try await session.send(command)
        } catch {
            sessions.removeValue(forKey: device.id)
            session.cancel()
            let replacement = try await makeSession(for: device)
            sessions[device.id] = replacement
            try await replacement.send(command)
        }
    }

    private func session(for device: RemoteDevice) async throws -> GoogleTVRemoteSession {
        if let session = sessions[device.id], session.isUsable { return session }
        sessions.removeValue(forKey: device.id)?.cancel()
        let session = try await makeSession(for: device)
        sessions[device.id] = session
        return session
    }

    private func makeSession(for device: RemoteDevice) async throws -> GoogleTVRemoteSession {
        guard let type = device.serviceType, let domain = device.serviceDomain else {
            throw RemoteCommandTransportError.deviceEndpointUnavailable
        }
        guard let certificateFingerprint = try credentialStore.fingerprint(for: device.id) else {
            throw RemoteCommandTransportError.notPaired
        }

        let resolver = await BonjourServiceResolver()
        let host = try await resolver.resolveHost(name: device.name, type: type, domain: domain)
        let identity = try identityStore.loadOrCreate()
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: Self.remotePort)
        let session = GoogleTVRemoteSession(
            endpoint: endpoint,
            identity: identity,
            expectedCertificateFingerprint: certificateFingerprint
        )
        try await session.start()
        return session
    }
}

nonisolated private final class GoogleTVRemoteSession: @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.pk.PK-Remote", category: "RemoteTransport")
    private let connection: NWConnection
    private let expectedCertificateFingerprint: Data
    private let trustCapture = RemoteTrustCapture()
    private let queue = DispatchQueue(label: "com.pk.PK-Remote.commands")
    private var receiveBuffer = Data()
    private var connectionContinuation: CheckedContinuation<Void, Error>?
    private var monitorTask: Task<Void, Never>?
    private let health = RemoteSessionHealth()
    private let imeState = RemoteIMEState()

    var isUsable: Bool { health.isUsable }

    init(
        endpoint: NWEndpoint,
        identity: PairingIdentity,
        expectedCertificateFingerprint: Data
    ) {
        self.expectedCertificateFingerprint = expectedCertificateFingerprint

        let tls = NWProtocolTLS.Options()
        sec_protocol_options_set_min_tls_protocol_version(
            tls.securityProtocolOptions,
            .TLSv12
        )
        if let protocolIdentity = sec_identity_create(identity.identity) {
            sec_protocol_options_set_local_identity(tls.securityProtocolOptions, protocolIdentity)
        }

        let trustCapture = self.trustCapture
        let expectedFingerprint = expectedCertificateFingerprint
        let queue = self.queue
        sec_protocol_options_set_verify_block(
            tls.securityProtocolOptions,
            { _, trust, complete in
                let trustReference = sec_trust_copy_ref(trust).takeRetainedValue()
                guard let chain = SecTrustCopyCertificateChain(trustReference) as? [SecCertificate],
                      let leafCertificate = chain.first else {
                    complete(false)
                    return
                }
                let certificateData = SecCertificateCopyData(leafCertificate) as Data
                let fingerprint = Data(SHA256.hash(data: certificateData))
                trustCapture.certificateMatches = fingerprint == expectedFingerprint
                complete(trustCapture.certificateMatches)
            },
            queue
        )

        let tcp = NWProtocolTCP.Options()
        tcp.noDelay = true
        tcp.enableKeepalive = true
        tcp.keepaliveIdle = 5
        connection = NWConnection(
            to: endpoint,
            using: NWParameters(tls: tls, tcp: tcp)
        )
    }

    deinit {
        monitorTask?.cancel()
        connection.cancel()
    }

    func start() async throws {
        print("[RemoteTransport] Connecting to port 6466")
        Self.logger.info("Connecting to the Google TV remote service")
        try await connect()
        guard trustCapture.certificateMatches else {
            throw RemoteCommandTransportError.certificateChanged
        }

        while true {
            let message = try RemoteProtocolCodec.decode(await receiveFrame())
            if try await handle(message) {
                health.isUsable = true
                print("[RemoteTransport] Session ready")
                Self.logger.info("Google TV remote session is ready")
                monitorTask = Task { [weak self] in
                    await self?.monitor()
                }
                return
            }
        }
    }

    func send(_ command: RemoteCommand) async throws {
        print("[RemoteTransport] Sending \(command.accessibilityLabel)")
        Self.logger.debug("Sending command: \(command.accessibilityLabel, privacy: .public)")
        switch command {
        case .text(let text):
            let counters = imeState.counters
            try await sendPayload(
                RemoteProtocolCodec.text(
                    text,
                    imeCounter: counters.imeCounter,
                    fieldCounter: counters.fieldCounter
                )
            )
        default:
            try await sendPayload(RemoteProtocolCodec.key(command))
        }
    }

    func cancel() {
        health.isUsable = false
        monitorTask?.cancel()
        connection.cancel()
    }

    private func connect() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connectionContinuation = continuation
            connection.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                switch state {
                case .ready:
                    connectionContinuation?.resume()
                    connectionContinuation = nil
                case .failed(let error):
                    connectionContinuation?.resume(
                        throwing: RemoteCommandTransportError.connectionFailed(error.localizedDescription)
                    )
                    connectionContinuation = nil
                case .cancelled:
                    connectionContinuation?.resume(
                        throwing: RemoteCommandTransportError.connectionFailed("Connection cancelled.")
                    )
                    connectionContinuation = nil
                default:
                    break
                }
            }
            connection.start(queue: queue)
        }
    }

    private func handle(_ message: RemoteProtocolMessage) async throws -> Bool {
        switch message {
        case .configure:
            try await sendPayload(RemoteProtocolCodec.configure())
            return true
        case .setActive(let value):
            try await sendPayload(RemoteProtocolCodec.setActive(value))
        case .ping(let value):
            try await sendPayload(RemoteProtocolCodec.pingResponse(value))
        case .imeBatchEdit(let imeCounter, let fieldCounter):
            imeState.update(imeCounter: imeCounter, fieldCounter: fieldCounter)
        case .other:
            break
        }
        return false
    }

    private func monitor() async {
        do {
            while !Task.isCancelled {
                let frame = try await receiveFrame()
                do {
                    let message = try RemoteProtocolCodec.decode(frame)
                    _ = try await handle(message)
                } catch is RemoteProtocolCodecError {
                    // Newer Google TV versions may add message shapes that this
                    // client does not consume. They must not tear down an otherwise
                    // healthy command session.
                    print("[RemoteTransport] Ignoring unsupported TV message: \(frame.hexadecimalString)")
                }
            }
        } catch {
            health.isUsable = false
            print("[RemoteTransport] Receive loop stopped: \(error.localizedDescription)")
            Self.logger.error("Remote receive loop stopped: \(error.localizedDescription, privacy: .public)")
            connection.cancel()
        }
    }

    private func sendPayload(_ payload: Data) async throws {
        let frame = RemoteProtocolCodec.frame(payload)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: frame, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(
                        throwing: RemoteCommandTransportError.connectionFailed(error.localizedDescription)
                    )
                } else {
                    continuation.resume()
                }
            })
        }
    }

    private func receiveFrame() async throws -> Data {
        if let frame = try RemoteProtocolCodec.extractFrame(from: &receiveBuffer) {
            return frame
        }
        return try await withCheckedThrowingContinuation { continuation in
            receiveMore(continuation)
        }
    }

    private func receiveMore(_ continuation: CheckedContinuation<Data, Error>) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            guard let self else {
                continuation.resume(
                    throwing: RemoteCommandTransportError.connectionFailed("Connection closed.")
                )
                return
            }
            if let data { receiveBuffer.append(data) }
            do {
                if let frame = try RemoteProtocolCodec.extractFrame(from: &receiveBuffer) {
                    continuation.resume(returning: frame)
                } else if let error {
                    continuation.resume(
                        throwing: RemoteCommandTransportError.connectionFailed(error.localizedDescription)
                    )
                } else if isComplete {
                    continuation.resume(
                        throwing: RemoteCommandTransportError.connectionFailed("The TV closed the connection.")
                    )
                } else {
                    receiveMore(continuation)
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

nonisolated private extension Data {
    var hexadecimalString: String {
        map { String(format: "%02X", $0) }.joined()
    }
}

nonisolated private final class RemoteTrustCapture: @unchecked Sendable {
    var certificateMatches = false
}

nonisolated private final class RemoteSessionHealth: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    var isUsable: Bool {
        get { lock.withLock { value } }
        set { lock.withLock { value = newValue } }
    }
}

nonisolated private final class RemoteIMEState: @unchecked Sendable {
    private let lock = NSLock()
    private var imeCounter = 0
    private var fieldCounter = 0

    var counters: (imeCounter: Int, fieldCounter: Int) {
        lock.withLock { (imeCounter, fieldCounter) }
    }

    func update(imeCounter: Int, fieldCounter: Int) {
        lock.withLock {
            self.imeCounter = imeCounter
            self.fieldCounter = fieldCounter
        }
    }
}
