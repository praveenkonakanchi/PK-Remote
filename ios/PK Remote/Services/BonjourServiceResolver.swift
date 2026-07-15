import Foundation

@MainActor
final class BonjourServiceResolver: NSObject, NetServiceDelegate {
    private var continuation: CheckedContinuation<String, Error>?
    private var service: NetService?

    func resolveHost(name: String, type: String, domain: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let service = NetService(domain: domain, type: type, name: name)
            self.service = service
            service.delegate = self
            service.resolve(withTimeout: 8)
        }
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        guard let host = sender.hostName?.trimmingCharacters(in: CharacterSet(charactersIn: ".")),
              !host.isEmpty else {
            finish(throwing: DevicePairingServiceError.serviceResolutionFailed)
            return
        }
        continuation?.resume(returning: host)
        cleanUp()
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        finish(throwing: DevicePairingServiceError.serviceResolutionFailed)
    }

    private func finish(throwing error: Error) {
        continuation?.resume(throwing: error)
        cleanUp()
    }

    private func cleanUp() {
        service?.stop()
        service?.delegate = nil
        service = nil
        continuation = nil
    }
}
