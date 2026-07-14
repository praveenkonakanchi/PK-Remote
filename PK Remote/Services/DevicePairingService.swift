import Foundation

protocol DevicePairingService: Sendable {
    func requestPairingCode(for device: RemoteDevice) async throws
    func pair(_ device: RemoteDevice, using code: String) async throws
    func cancelPairing(for device: RemoteDevice) async
}

enum DevicePairingServiceError: LocalizedError {
    case transportUnavailable

    var errorDescription: String? {
        switch self {
        case .transportUnavailable:
            "Secure pairing is not available yet."
        }
    }
}

struct UnavailableDevicePairingService: DevicePairingService {
    func requestPairingCode(for device: RemoteDevice) async throws {
        throw DevicePairingServiceError.transportUnavailable
    }

    func pair(_ device: RemoteDevice, using code: String) async throws {
        throw DevicePairingServiceError.transportUnavailable
    }

    func cancelPairing(for device: RemoteDevice) async {}
}

struct PreviewDevicePairingService: DevicePairingService {
    func requestPairingCode(for device: RemoteDevice) async throws {
        // Preview-only success path; no network traffic is performed.
    }

    func pair(_ device: RemoteDevice, using code: String) async throws {
        // Input is validated by AppState; no network traffic is performed.
    }

    func cancelPairing(for device: RemoteDevice) async {}
}
