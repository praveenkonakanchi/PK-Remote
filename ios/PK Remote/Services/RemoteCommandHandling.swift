protocol RemoteCommandHandling: Sendable {
    func send(_ command: RemoteCommand, to device: RemoteDevice) async throws
}

struct LocalRemoteCommandHandler: RemoteCommandHandling {
    func send(_ command: RemoteCommand, to device: RemoteDevice) async throws {}
}
