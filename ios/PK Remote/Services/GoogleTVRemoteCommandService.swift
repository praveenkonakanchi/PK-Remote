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
    case pairingRejected
    case unsupportedCommand
    case appLaunchRejected
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
        case .pairingRejected:
            "The TV no longer accepts this app's pairing certificate. Pair the TV again."
        case .unsupportedCommand:
            "This remote command is not supported."
        case .appLaunchRejected:
            "The TV could not open this shortcut. Edit or remove it and try again."
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
    private var settingsPressesInProgress: Set<RemoteDevice.ID> = []

    init(
        identityStore: PairingIdentityStore = PairingIdentityStore(),
        credentialStore: PairingCredentialStore = PairingCredentialStore()
    ) {
        self.identityStore = identityStore
        self.credentialStore = credentialStore
    }

    func send(_ command: RemoteCommand, to device: RemoteDevice) async throws {
        let isSettingsLongPress = command == .openGoogleTVSettings
        if isSettingsLongPress {
            guard settingsPressesInProgress.insert(device.id).inserted else { return }
        }
        defer {
            if isSettingsLongPress { settingsPressesInProgress.remove(device.id) }
        }

        let session = try await session(for: device)
        do {
            try await session.send(command)
        } catch {
            if !command.retriesAfterTransportFailure {
                if error.isPairingInvalidation {
                    sessions.removeValue(forKey: device.id)
                    session.cancel()
                }
                throw error
            }
            sessions.removeValue(forKey: device.id)
            session.cancel()
            if error.isPairingInvalidation {
                throw error
            }
            let replacement = try await makeSession(for: device)
            sessions[device.id] = replacement
            try await replacement.send(command)
        }
    }

    func stopSession(for device: RemoteDevice) async {
        sessions.removeValue(forKey: device.id)?.cancel()
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
        guard let certificateFingerprint = try credentialStore.tvCertificateFingerprint(for: device.id) else {
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
    private let appLaunchFeedback = RemoteAppLaunchFeedback()

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
                let matches = fingerprint == expectedFingerprint
                trustCapture.recordCertificate(matches: matches)
                complete(matches)
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
        case .launchApp(let identifier):
            await appLaunchFeedback.begin()
            do {
                try await sendPayload(RemoteProtocolCodec.appLink(identifier))
                try await appLaunchFeedback.waitForImmediateResult()
            } catch {
                await appLaunchFeedback.cancel()
                throw error
            }
        case .openGoogleTVSettings:
            try await sendPayload(
                RemoteProtocolCodec.key(command, direction: .startLong)
            )
            do {
                try await Task.sleep(nanoseconds: 650_000_000)
            } catch {
                try? await sendPayload(
                    RemoteProtocolCodec.key(command, direction: .endLong)
                )
                throw error
            }
            try await sendPayload(
                RemoteProtocolCodec.key(command, direction: .endLong)
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
                    let transportError: RemoteCommandTransportError
                    if trustCapture.receivedCertificate && !trustCapture.certificateMatches {
                        transportError = .certificateChanged
                    } else if error.isPairingCertificateRejection {
                        transportError = .pairingRejected
                    } else {
                        transportError = .connectionFailed(error.localizedDescription)
                    }
                    connectionContinuation?.resume(
                        throwing: transportError
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
        case .remoteError(let isError, let originalField):
            print(
                "[RemoteTransport] TV response for field \(originalField ?? -1): "
                    + (isError ? "rejected" : "accepted")
            )
            if originalField == 90 {
                if isError {
                    await appLaunchFeedback.reject()
                } else {
                    await appLaunchFeedback.acknowledge()
                }
            }
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

private actor RemoteAppLaunchFeedback {
    private var isPending = false
    private var wasRejected = false
    private var continuation: CheckedContinuation<Void, Error>?
    private var timeoutTask: Task<Void, Never>?

    func begin() {
        finishPendingIfNeeded()
        isPending = true
        wasRejected = false
    }

    func waitForImmediateResult() async throws {
        guard isPending else { return }
        if wasRejected {
            isPending = false
            throw RemoteCommandTransportError.appLaunchRejected
        }
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            timeoutTask = Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                self.accept()
            }
        }
    }

    func reject() {
        guard isPending else { return }
        wasRejected = true
        guard let continuation else { return }
        timeoutTask?.cancel()
        clear()
        continuation.resume(throwing: RemoteCommandTransportError.appLaunchRejected)
    }

    func acknowledge() {
        accept()
    }

    func cancel() {
        guard let continuation else {
            clear()
            return
        }
        clear()
        continuation.resume(throwing: CancellationError())
    }

    private func accept() {
        guard isPending, let continuation else { return }
        clear()
        continuation.resume()
    }

    private func finishPendingIfNeeded() {
        guard let continuation else {
            clear()
            return
        }
        clear()
        continuation.resume()
    }

    private func clear() {
        timeoutTask?.cancel()
        timeoutTask = nil
        continuation = nil
        isPending = false
        wasRejected = false
    }
}

nonisolated private extension Error {
    var isPairingInvalidation: Bool {
        guard let error = self as? RemoteCommandTransportError else { return false }
        return switch error {
        case .certificateChanged, .pairingRejected, .notPaired:
            true
        default:
            false
        }
    }
}

nonisolated private extension NWError {
    var isPairingCertificateRejection: Bool {
        guard case .tls(let status) = self else { return false }
        return status == errSSLPeerBadCert
            || status == errSSLPeerUnsupportedCert
            || status == errSSLPeerCertUnknown
            || status == errSSLPeerUnknownCA
            || status == errSSLPeerAccessDenied
    }
}

nonisolated private extension Data {
    var hexadecimalString: String {
        map { String(format: "%02X", $0) }.joined()
    }
}

nonisolated private final class RemoteTrustCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var received = false
    private var matches = false

    var receivedCertificate: Bool { lock.withLock { received } }
    var certificateMatches: Bool { lock.withLock { matches } }

    func recordCertificate(matches: Bool) {
        lock.withLock {
            received = true
            self.matches = matches
        }
    }
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
