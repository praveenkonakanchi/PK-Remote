protocol RemoteCommandHandling: Sendable {
    func send(_ command: RemoteCommand) async throws
}

struct LocalRemoteCommandHandler: RemoteCommandHandling {
    func send(_ command: RemoteCommand) async throws {
        // Intentionally local-only until a remote transport milestone is implemented.
    }
}
