import Foundation

@MainActor
protocol DeviceDiscovering: AnyObject {
    typealias UpdateHandler = @Sendable (Result<[RemoteDevice], Error>) -> Void

    func start(onUpdate: @escaping UpdateHandler)
    func stop()
}

@MainActor
final class PlaceholderDeviceDiscovery: DeviceDiscovering {
    func start(onUpdate: @escaping UpdateHandler) {
        onUpdate(.success([.placeholder]))
    }

    func stop() {}
}
