import CryptoKit
import Foundation
import Network
import Security

actor GoogleTVPairingService: DevicePairingService {
    private nonisolated static let pairingPort = NWEndpoint.Port(rawValue: 6467)!
    private let identityStore: PairingIdentityStore
    private let credentialStore: PairingCredentialStore
    private var sessions: [RemoteDevice.ID: GoogleTVPairingSession] = [:]

    init(
        identityStore: PairingIdentityStore = PairingIdentityStore(),
        credentialStore: PairingCredentialStore = PairingCredentialStore()
    ) {
        self.identityStore = identityStore
        self.credentialStore = credentialStore
    }

    func requestPairingCode(for device: RemoteDevice) async throws {
        guard let type = device.serviceType, let domain = device.serviceDomain else {
            throw DevicePairingServiceError.deviceEndpointUnavailable
        }

        let resolver = await BonjourServiceResolver()
        let host = try await resolver.resolveHost(name: device.name, type: type, domain: domain)
        let identity = try identityStore.loadOrCreate()
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: Self.pairingPort)
        let session = GoogleTVPairingSession(endpoint: endpoint, identity: identity)
        sessions[device.id]?.cancel()
        sessions[device.id] = session

        do {
            try await session.start(clientName: "PK Remote")
        } catch {
            sessions.removeValue(forKey: device.id)
            session.cancel()
            throw error
        }
    }

    func pair(_ device: RemoteDevice, using code: String) async throws {
        guard let session = sessions[device.id] else {
            throw DevicePairingServiceError.pairingSessionMissing
        }
        defer {
            sessions.removeValue(forKey: device.id)
            session.cancel()
        }
        let certificateFingerprint = try await session.finish(code: code)
        try credentialStore.save(certificateFingerprint, for: device.id)
    }

    func cancelPairing(for device: RemoteDevice) async {
        sessions.removeValue(forKey: device.id)?.cancel()
    }
}

nonisolated private final class GoogleTVPairingSession: @unchecked Sendable {
    private let connection: NWConnection
    private let identity: PairingIdentity
    private let peerKeyCapture: PeerPublicKeyCapture
    private let queue = DispatchQueue(label: "com.pk.PK-Remote.pairing")
    private var receiveBuffer = Data()
    private var connectionContinuation: CheckedContinuation<Void, Error>?

    init(endpoint: NWEndpoint, identity: PairingIdentity) {
        self.identity = identity
        let peerKeyCapture = PeerPublicKeyCapture()
        self.peerKeyCapture = peerKeyCapture

        let tls = NWProtocolTLS.Options()
        sec_protocol_options_set_min_tls_protocol_version(
            tls.securityProtocolOptions,
            .TLSv12
        )
        if let protocolIdentity = sec_identity_create(identity.identity) {
            sec_protocol_options_set_local_identity(tls.securityProtocolOptions, protocolIdentity)
        }

        let queue = self.queue
        sec_protocol_options_set_verify_block(
            tls.securityProtocolOptions,
            { _, trust, complete in
                let trustReference = sec_trust_copy_ref(trust).takeRetainedValue()
                if let publicKey = SecTrustCopyKey(trustReference) {
                    var error: Unmanaged<CFError>?
                    peerKeyCapture.key = SecKeyCopyExternalRepresentation(publicKey, &error) as Data?
                }
                if let chain = SecTrustCopyCertificateChain(trustReference) as? [SecCertificate],
                   let leafCertificate = chain.first {
                    let certificateData = SecCertificateCopyData(leafCertificate) as Data
                    peerKeyCapture.certificateFingerprint = Data(SHA256.hash(data: certificateData))
                }
                complete(
                    peerKeyCapture.key != nil
                        && peerKeyCapture.certificateFingerprint != nil
                )
            },
            queue
        )

        self.connection = NWConnection(
            to: endpoint,
            using: NWParameters(tls: tls, tcp: NWProtocolTCP.Options())
        )
    }

    func start(clientName: String) async throws {
        try await connect()
        try await send(PairingProtocolCodec.pairingRequest(clientName: clientName))

        while true {
            switch try await receiveKind() {
            case .pairingRequestAcknowledgement:
                try await send(PairingProtocolCodec.options())
            case .options:
                try await send(PairingProtocolCodec.configuration())
            case .configurationAcknowledgement:
                return
            default:
                throw DevicePairingServiceError.protocolFailure
            }
        }
    }

    func finish(code: String) async throws -> Data {
        guard let peerPublicKey = peerKeyCapture.key,
              let certificateFingerprint = peerKeyCapture.certificateFingerprint else {
            throw DevicePairingServiceError.protocolFailure
        }
        let secret = try PairingSecret.make(
            code: code,
            clientPublicKey: identity.publicKey,
            serverPublicKey: peerPublicKey
        )
        try await send(PairingProtocolCodec.secret(secret))
        guard try await receiveKind() == .secretAcknowledgement else {
            throw DevicePairingServiceError.invalidPairingCode
        }
        return certificateFingerprint
    }

    func cancel() {
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
                        throwing: DevicePairingServiceError.connectionFailed(error.localizedDescription)
                    )
                    connectionContinuation = nil
                case .cancelled:
                    connectionContinuation?.resume(
                        throwing: DevicePairingServiceError.connectionFailed("Connection cancelled.")
                    )
                    connectionContinuation = nil
                default:
                    break
                }
            }
            connection.start(queue: queue)
        }
    }

    private func send(_ payload: Data) async throws {
        let frame = PairingProtocolCodec.frame(payload)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: frame, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(
                        throwing: DevicePairingServiceError.connectionFailed(error.localizedDescription)
                    )
                } else {
                    continuation.resume()
                }
            })
        }
    }

    private func receiveKind() async throws -> PairingMessageKind {
        try PairingProtocolCodec.decodeKind(from: await receiveFrame())
    }

    private func receiveFrame() async throws -> Data {
        if let frame = try PairingProtocolCodec.extractFrame(from: &receiveBuffer) {
            return frame
        }

        return try await withCheckedThrowingContinuation { continuation in
            receiveMore(continuation)
        }
    }

    private func receiveMore(_ continuation: CheckedContinuation<Data, Error>) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            guard let self else {
                continuation.resume(throwing: DevicePairingServiceError.connectionFailed("Connection closed."))
                return
            }
            if let data { receiveBuffer.append(data) }
            do {
                if let frame = try PairingProtocolCodec.extractFrame(from: &receiveBuffer) {
                    continuation.resume(returning: frame)
                } else if let error {
                    continuation.resume(
                        throwing: DevicePairingServiceError.connectionFailed(error.localizedDescription)
                    )
                } else if isComplete {
                    continuation.resume(
                        throwing: DevicePairingServiceError.connectionFailed("The TV closed the connection.")
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

nonisolated private final class PeerPublicKeyCapture: @unchecked Sendable {
    var key: Data?
    var certificateFingerprint: Data?
}

nonisolated private enum PairingSecret {
    static func make(code: String, clientPublicKey: Data, serverPublicKey: Data) throws -> Data {
        guard code.count == 6,
              let expectedFirstByte = UInt8(code.prefix(2), radix: 16),
              let codeSuffix = Data(hexadecimal: String(code.suffix(4))) else {
            throw DevicePairingServiceError.invalidPairingCode
        }

        let client = try RSAPublicKeyComponents(data: clientPublicKey)
        let server = try RSAPublicKeyComponents(data: serverPublicKey)
        var hashInput = Data()
        hashInput.append(client.modulus)
        hashInput.append(client.exponent)
        hashInput.append(server.modulus)
        hashInput.append(server.exponent)
        hashInput.append(codeSuffix)
        let digest = Data(SHA256.hash(data: hashInput))
        guard digest.first == expectedFirstByte else {
            throw DevicePairingServiceError.invalidPairingCode
        }
        return digest
    }
}

nonisolated private struct RSAPublicKeyComponents {
    let modulus: Data
    let exponent: Data

    init(data: Data) throws {
        var reader = DERReader(data: data)
        let sequence = try reader.read(tag: 0x30)
        var components = DERReader(data: sequence)
        modulus = Self.normalized(try components.read(tag: 0x02))
        exponent = Self.normalized(try components.read(tag: 0x02))
    }

    private static func normalized(_ data: Data) -> Data {
        var bytes = Data(data.drop(while: { $0 == 0 }))
        if bytes.isEmpty { bytes = Data([0]) }
        return bytes
    }
}

nonisolated private struct DERReader {
    private let data: Data
    private var index = 0

    init(data: Data) {
        self.data = data
    }

    mutating func read(tag expectedTag: UInt8) throws -> Data {
        guard index < data.count, data[index] == expectedTag else {
            throw PairingIdentityError.invalidPublicKey
        }
        index += 1
        let length = try readLength()
        guard index + length <= data.count else { throw PairingIdentityError.invalidPublicKey }
        defer { index += length }
        return data.subdata(in: index..<(index + length))
    }

    private mutating func readLength() throws -> Int {
        guard index < data.count else { throw PairingIdentityError.invalidPublicKey }
        let first = data[index]
        index += 1
        if first & 0x80 == 0 { return Int(first) }
        let byteCount = Int(first & 0x7f)
        guard byteCount > 0, byteCount <= 4, index + byteCount <= data.count else {
            throw PairingIdentityError.invalidPublicKey
        }
        var length = 0
        for _ in 0..<byteCount {
            length = (length << 8) | Int(data[index])
            index += 1
        }
        return length
    }
}

nonisolated private extension Data {
    init?(hexadecimal: String) {
        guard hexadecimal.count.isMultiple(of: 2) else { return nil }
        var bytes: [UInt8] = []
        var index = hexadecimal.startIndex
        while index < hexadecimal.endIndex {
            let next = hexadecimal.index(index, offsetBy: 2)
            guard let byte = UInt8(hexadecimal[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        self.init(bytes)
    }
}
