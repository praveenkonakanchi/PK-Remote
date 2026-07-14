protocol DeviceDiscovering: Sendable {
    func discover() async throws -> [RemoteDevice]
}

struct PlaceholderDeviceDiscovery: DeviceDiscovering {
    func discover() async throws -> [RemoteDevice] {
        [.placeholder]
    }
}
