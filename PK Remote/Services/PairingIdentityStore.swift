import Foundation
import Security
import X509

nonisolated struct PairingIdentity: @unchecked Sendable {
    let identity: SecIdentity
    let privateKey: SecKey
    let publicKey: Data
}

nonisolated enum PairingIdentityError: LocalizedError {
    case keyGenerationFailed(String)
    case certificateCreationFailed
    case keychain(OSStatus)
    case invalidPublicKey

    var errorDescription: String? {
        switch self {
        case .keyGenerationFailed(let message): message
        case .certificateCreationFailed: "Could not create the pairing certificate."
        case .keychain(let status): "Keychain error: \(status)."
        case .invalidPublicKey: "The pairing certificate contains an invalid public key."
        }
    }
}

nonisolated struct PairingIdentityStore: Sendable {
    private static let applicationTag = Data("com.pk.PK-Remote.google-tv-identity.v3".utf8)
    private static let certificateLabel = "PK Remote Google TV Identity v3"

    func loadOrCreate() throws -> PairingIdentity {
        if let privateKey = try loadPrivateKey(), let certificate = try loadCertificate() {
            return try makeIdentity(certificate: certificate, privateKey: privateKey)
        }

        clearIncompleteIdentity()
        return try createIdentity()
    }

    func makeEphemeralForTesting() throws -> PairingIdentity {
        var error: Unmanaged<CFError>?
        let attributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits: 2048
        ]
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw PairingIdentityError.keyGenerationFailed(
                error?.takeRetainedValue().localizedDescription ?? "Could not generate a pairing key."
            )
        }
        return try makeIdentity(
            certificate: SelfSignedCertificate.make(privateKey: privateKey),
            privateKey: privateKey
        )
    }

    private func createIdentity() throws -> PairingIdentity {
        var error: Unmanaged<CFError>?
        let attributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits: 2048,
            kSecPrivateKeyAttrs: [
                kSecAttrIsPermanent: true,
                kSecAttrApplicationTag: Self.applicationTag,
                kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            ]
        ]
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw PairingIdentityError.keyGenerationFailed(
                error?.takeRetainedValue().localizedDescription ?? "Could not generate a pairing key."
            )
        }

        do {
            let certificate = try SelfSignedCertificate.make(privateKey: privateKey)
            let addStatus = SecItemAdd([
                kSecClass: kSecClassCertificate,
                kSecAttrLabel: Self.certificateLabel,
                kSecValueRef: certificate,
                kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            ] as CFDictionary, nil)
            guard addStatus == errSecSuccess || addStatus == errSecDuplicateItem else {
                throw PairingIdentityError.keychain(addStatus)
            }
            return try makeIdentity(certificate: certificate, privateKey: privateKey)
        } catch {
            SecItemDelete([
                kSecClass: kSecClassKey,
                kSecAttrApplicationTag: Self.applicationTag
            ] as CFDictionary)
            throw error
        }
    }

    private func makeIdentity(certificate: SecCertificate, privateKey: SecKey) throws -> PairingIdentity {
        guard let identity = SecIdentityCreate(nil, certificate, privateKey),
              let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw PairingIdentityError.certificateCreationFailed
        }
        var error: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            throw PairingIdentityError.invalidPublicKey
        }
        return PairingIdentity(identity: identity, privateKey: privateKey, publicKey: publicKeyData)
    }

    private func loadPrivateKey() throws -> SecKey? {
        var result: CFTypeRef?
        let status = SecItemCopyMatching([
            kSecClass: kSecClassKey,
            kSecAttrApplicationTag: Self.applicationTag,
            kSecReturnRef: true,
            kSecMatchLimit: kSecMatchLimitOne
        ] as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw PairingIdentityError.keychain(status) }
        guard let result, CFGetTypeID(result) == SecKeyGetTypeID() else {
            throw PairingIdentityError.keychain(errSecInternalError)
        }
        return unsafeBitCast(result, to: SecKey.self)
    }

    private func loadCertificate() throws -> SecCertificate? {
        var result: CFTypeRef?
        let status = SecItemCopyMatching([
            kSecClass: kSecClassCertificate,
            kSecAttrLabel: Self.certificateLabel,
            kSecReturnRef: true,
            kSecMatchLimit: kSecMatchLimitOne
        ] as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw PairingIdentityError.keychain(status) }
        guard let result, CFGetTypeID(result) == SecCertificateGetTypeID() else {
            throw PairingIdentityError.keychain(errSecInternalError)
        }
        return unsafeBitCast(result, to: SecCertificate.self)
    }

    private func clearIncompleteIdentity() {
        SecItemDelete([
            kSecClass: kSecClassKey,
            kSecAttrApplicationTag: Self.applicationTag
        ] as CFDictionary)
        SecItemDelete([
            kSecClass: kSecClassCertificate,
            kSecAttrLabel: Self.certificateLabel
        ] as CFDictionary)
    }
}

nonisolated private enum SelfSignedCertificate {
    static func make(privateKey: SecKey) throws -> SecCertificate {
        let signingKey = try Certificate.PrivateKey(privateKey)
        let name = try DistinguishedName { CommonName("PK Remote") }
        let now = Date()
        let certificate = try Certificate(
            version: .v3,
            serialNumber: .init(),
            publicKey: signingKey.publicKey,
            notValidBefore: now.addingTimeInterval(-86_400),
            notValidAfter: now.addingTimeInterval(86_400 * 3_650),
            issuer: name,
            subject: name,
            signatureAlgorithm: .sha256WithRSAEncryption,
            extensions: Certificate.Extensions {},
            issuerPrivateKey: signingKey
        )
        return try SecCertificate.makeWithCertificate(certificate)
    }
}
