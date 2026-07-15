nonisolated protocol RemoteCommandHandling: Sendable {
    func send(_ command: RemoteCommand, to device: RemoteDevice) async throws
    func stopSession(for device: RemoteDevice) async
}

nonisolated extension RemoteCommandHandling {
    func stopSession(for device: RemoteDevice) async {}
}

struct LocalRemoteCommandHandler: RemoteCommandHandling {
    func send(_ command: RemoteCommand, to device: RemoteDevice) async throws {}
    func stopSession(for device: RemoteDevice) async {}
}
