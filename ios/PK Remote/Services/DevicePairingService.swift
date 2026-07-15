import Foundation

protocol DevicePairingService: Sendable {
    func requestPairingCode(for device: RemoteDevice) async throws
    func pair(_ device: RemoteDevice, using code: String) async throws
    func cancelPairing(for device: RemoteDevice) async
}

enum DevicePairingServiceError: LocalizedError {
    case transportUnavailable
    case deviceEndpointUnavailable
    case serviceResolutionFailed
    case connectionFailed(String)
    case invalidPairingCode
    case pairingSessionMissing
    case protocolFailure

    var errorDescription: String? {
        switch self {
        case .transportUnavailable:
            "Secure pairing is not available yet."
        case .deviceEndpointUnavailable:
            "The TV pairing service could not be resolved. Refresh Devices and try again."
        case .serviceResolutionFailed:
            "The TV hostname could not be resolved. Make sure it is on the same Wi-Fi network."
        case .connectionFailed(let message):
            "Could not connect to the TV: \(message)"
        case .invalidPairingCode:
            "The pairing code was not accepted. Check the code on your TV and try again."
        case .pairingSessionMissing:
            "The pairing session expired. Start pairing again."
        case .protocolFailure:
            "The TV returned an unexpected pairing response."
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
