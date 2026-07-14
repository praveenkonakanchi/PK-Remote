import Foundation
import Security

nonisolated struct PairingCredentialStore: Sendable {
    private static let service = "com.pk.PK-Remote.google-tv-certificate-fingerprint.v1"

    func save(_ certificateFingerprint: Data, for deviceID: RemoteDevice.ID) throws {
        let lookup = query(for: deviceID)
        let updateStatus = SecItemUpdate(
            lookup as CFDictionary,
            [kSecValueData: certificateFingerprint] as CFDictionary
        )
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw PairingIdentityError.keychain(updateStatus)
        }

        var item = lookup
        item[kSecValueData] = certificateFingerprint
        item[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(item as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw PairingIdentityError.keychain(addStatus)
        }
    }

    func fingerprint(for deviceID: RemoteDevice.ID) throws -> Data? {
        var lookup = query(for: deviceID)
        lookup[kSecReturnData] = true
        lookup[kSecMatchLimit] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(lookup as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw PairingIdentityError.keychain(status)
        }
        return result as? Data
    }

    private func query(for deviceID: RemoteDevice.ID) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Self.service,
            kSecAttrAccount: String(describing: deviceID)
        ]
    }
}
