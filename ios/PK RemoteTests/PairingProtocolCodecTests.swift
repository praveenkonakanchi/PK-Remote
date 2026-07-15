import Foundation
import Security
import Testing
@testable import PK_Remote

struct PairingProtocolCodecTests {
    @Test func pairingRequestUsesDelimitedProtobufV2Envelope() throws {
        let payload = PairingProtocolCodec.pairingRequest(clientName: "PK Remote")
        var frame = PairingProtocolCodec.frame(payload)

        #expect(try PairingProtocolCodec.extractFrame(from: &frame) == payload)
        #expect(frame.isEmpty)
        #expect(payload.starts(with: [0x08, 0x02, 0x10, 0xc8, 0x01, 0x52]))
    }

    @Test func decoderRecognizesPairingAcknowledgements() throws {
        let acknowledgement = Data([0x08, 0x02, 0x10, 0xc8, 0x01, 0x5a, 0x00])

        #expect(
            try PairingProtocolCodec.decodeKind(from: acknowledgement)
                == .pairingRequestAcknowledgement
        )
    }

    @Test func frameExtractionWaitsForCompletePayload() throws {
        let payload = PairingProtocolCodec.configuration()
        let completeFrame = PairingProtocolCodec.frame(payload)
        let partialFrame = completeFrame.dropLast()
        var data = Data(partialFrame)

        #expect(try PairingProtocolCodec.extractFrame(from: &data) == nil)
        #expect(data == Data(partialFrame))
    }

    @Test func identityCertificateMatchesPrivateKey() throws {
        let store = PairingIdentityStore()
        let identity = try store.makeEphemeralForTesting()

        var recoveredPrivateKey: SecKey?
        var recoveredCertificate: SecCertificate?
        #expect(SecIdentityCopyPrivateKey(identity.identity, &recoveredPrivateKey) == errSecSuccess)
        #expect(SecIdentityCopyCertificate(identity.identity, &recoveredCertificate) == errSecSuccess)

        #expect(identity.publicKey.count >= 256)
        #expect(recoveredPrivateKey != nil)
        #expect(recoveredCertificate != nil)

        let certificatePublicKey = try #require(SecCertificateCopyKey(recoveredCertificate!))
        var publicKeyError: Unmanaged<CFError>?
        let certificatePublicKeyData = try #require(
            SecKeyCopyExternalRepresentation(certificatePublicKey, &publicKeyError) as Data?
        )
        #expect(certificatePublicKeyData == identity.publicKey)
    }

#if !targetEnvironment(simulator)
    @Test func productionIdentitySurvivesAStoreRelaunch() throws {
        let first = try PairingIdentityStore().loadOrCreate()
        let second = try PairingIdentityStore().loadOrCreate()

        #expect(first.publicKey == second.publicKey)
        var recoveredPrivateKey: SecKey?
        var recoveredCertificate: SecCertificate?
        #expect(SecIdentityCopyPrivateKey(second.identity, &recoveredPrivateKey) == errSecSuccess)
        #expect(SecIdentityCopyCertificate(second.identity, &recoveredCertificate) == errSecSuccess)
        #expect(recoveredPrivateKey != nil)
        #expect(recoveredCertificate != nil)
    }

    @Test func productionCredentialSurvivesRelaunchAndRemainsBoundToIdentity() throws {
        let deviceID = "credential-test-\(UUID().uuidString)"
        let identity = try PairingIdentityStore().loadOrCreate()
        let firstStore = PairingCredentialStore()
        let tvFingerprint = Data(repeating: 0xA5, count: 32)
        defer { try? firstStore.removePairing(for: deviceID) }

        try firstStore.save(
            tvCertificateFingerprint: tvFingerprint,
            clientCertificateFingerprint: identity.certificateFingerprint,
            for: deviceID
        )

        let relaunchedStore = PairingCredentialStore()
        #expect(relaunchedStore.isPaired(deviceID: deviceID))
        #expect(try relaunchedStore.tvCertificateFingerprint(for: deviceID) == tvFingerprint)

        try relaunchedStore.removePairing(for: deviceID)
        #expect(!relaunchedStore.isPaired(deviceID: deviceID))
    }
#endif
}
