import Foundation
import Testing
@testable import PK_Remote

@MainActor
struct AppStateTests {
    @Test func startsReadyForDiscovery() {
        let state = AppState()

        #expect(state.devices.isEmpty)
        #expect(state.selectedDevice == nil)
        #expect(state.discoveryState == .idle)
        #expect(state.lastActionDescription == "Ready")
    }

    @Test func forwardsCommandsAndRecordsSuccessfulAction() async {
        let handler = RecordingCommandHandler()
        let state = AppState(commandHandler: handler)

        await state.send(.volumeUp)

        #expect(await handler.commands == [.volumeUp])
        #expect(state.lastCommand == .volumeUp)
        #expect(state.lastActionDescription == "Volume up")
        #expect(state.commandError == nil)
    }

    @Test func preservesLastCommandWhenSendingFails() async {
        let state = AppState(commandHandler: FailingCommandHandler())

        await state.send(.power)

        #expect(state.lastCommand == nil)
        #expect(state.commandError == TestFailure.command.localizedDescription)
    }

    @Test func discoveryReplacesDevicesAndSelectsFirstResult() async {
        let livingRoom = RemoteDevice(name: "Living Room")
        let discovery = StubDeviceDiscovery()
        let state = AppState(devices: [.placeholder], deviceDiscovery: discovery)

        state.startDiscovery()
        #expect(state.discoveryState == .searching)
        discovery.send(.success([livingRoom, livingRoom]))
        await settle()

        #expect(state.devices == [livingRoom])
        #expect(state.selectedDevice == livingRoom)
        #expect(state.discoveryState == .idle)
    }

    @Test func discoveryExposesFailureWithoutDiscardingDevices() async {
        let discovery = StubDeviceDiscovery()
        let state = AppState(devices: [.placeholder], deviceDiscovery: discovery)

        state.startDiscovery()
        discovery.send(.failure(TestFailure.discovery))
        await settle()

        #expect(state.devices == [.placeholder])
        #expect(state.discoveryState == .failed(TestFailure.discovery.localizedDescription))
    }

    @Test func stoppingDiscoveryReturnsSearchingStateToIdle() {
        let discovery = StubDeviceDiscovery()
        let state = AppState(deviceDiscovery: discovery)

        state.startDiscovery()
        state.stopDiscovery()

        #expect(discovery.stopCallCount == 1)
        #expect(state.discoveryState == .idle)
    }

    private func settle() async {
        for _ in 0..<10 { await Task.yield() }
    }
}

private actor RecordingCommandHandler: RemoteCommandHandling {
    private(set) var commands: [RemoteCommand] = []

    func send(_ command: RemoteCommand) async throws {
        commands.append(command)
    }
}

private struct FailingCommandHandler: RemoteCommandHandling {
    func send(_ command: RemoteCommand) async throws {
        throw TestFailure.command
    }
}

@MainActor
private final class StubDeviceDiscovery: DeviceDiscovering {
    private var onUpdate: UpdateHandler?
    private(set) var stopCallCount = 0

    func start(onUpdate: @escaping UpdateHandler) {
        self.onUpdate = onUpdate
    }

    func stop() {
        stopCallCount += 1
    }

    func send(_ result: Result<[RemoteDevice], Error>) {
        onUpdate?(result)
    }
}

private enum TestFailure: Error {
    case command
    case discovery
}
