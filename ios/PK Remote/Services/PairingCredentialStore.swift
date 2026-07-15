import Foundation
import Security

nonisolated protocol PairingCredentialChecking: Sendable {
    func isPaired(deviceID: RemoteDevice.ID) -> Bool
    func removePairing(for deviceID: RemoteDevice.ID) throws
}

nonisolated struct PairingCredentialStore: Sendable {
    private struct StoredCredential: Codable {
        let tvCertificateFingerprint: Data
        let clientCertificateFingerprint: Data
    }

    private static let service = "com.pk.PK-Remote.google-tv-pairing-credential.v2"
    private static let legacyService = "com.pk.PK-Remote.google-tv-certificate-fingerprint.v1"
    private let identityStore: PairingIdentityStore

    init(identityStore: PairingIdentityStore = PairingIdentityStore()) {
        self.identityStore = identityStore
    }

    func save(
        tvCertificateFingerprint: Data,
        clientCertificateFingerprint: Data,
        for deviceID: RemoteDevice.ID
    ) throws {
        let encodedCredential = try JSONEncoder().encode(
            StoredCredential(
                tvCertificateFingerprint: tvCertificateFingerprint,
                clientCertificateFingerprint: clientCertificateFingerprint
            )
        )
        let lookup = query(for: deviceID)
        let updateStatus = SecItemUpdate(
            lookup as CFDictionary,
            [kSecValueData: encodedCredential] as CFDictionary
        )
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw PairingIdentityError.keychain(updateStatus)
        }

        var item = lookup
        item[kSecValueData] = encodedCredential
        item[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(item as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw PairingIdentityError.keychain(addStatus)
        }
    }

    func tvCertificateFingerprint(for deviceID: RemoteDevice.ID) throws -> Data? {
        guard let credential = try credential(for: deviceID),
              credential.clientCertificateFingerprint == (try identityStore.loadOrCreate()).certificateFingerprint else {
            return nil
        }
        return credential.tvCertificateFingerprint
    }

    func removePairing(for deviceID: RemoteDevice.ID) throws {
        for service in [Self.service, Self.legacyService] {
            let status = SecItemDelete(query(for: deviceID, service: service) as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw PairingIdentityError.keychain(status)
            }
        }
    }

    private func credential(for deviceID: RemoteDevice.ID) throws -> StoredCredential? {
        var lookup = query(for: deviceID)
        lookup[kSecReturnData] = true
        lookup[kSecMatchLimit] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(lookup as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw PairingIdentityError.keychain(status)
        }
        guard let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(StoredCredential.self, from: data)
    }

    private func query(
        for deviceID: RemoteDevice.ID,
        service: String = Self.service
    ) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: String(describing: deviceID)
        ]
    }
}

nonisolated extension PairingCredentialStore: PairingCredentialChecking {
    func isPaired(deviceID: RemoteDevice.ID) -> Bool {
        (try? tvCertificateFingerprint(for: deviceID)) != nil
    }
}
