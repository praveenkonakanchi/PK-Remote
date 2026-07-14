import Foundation
import Testing
@testable import PK_Remote

@MainActor
struct AppStateTests {
    @Test func startsWithPlaceholderDeviceSelected() {
        let state = AppState()

        #expect(state.devices == [.placeholder])
        #expect(state.selectedDevice == .placeholder)
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
        let state = AppState(
            devices: [.placeholder],
            deviceDiscovery: StubDeviceDiscovery(result: .success([livingRoom]))
        )

        await state.discoverDevices()

        #expect(state.devices == [livingRoom])
        #expect(state.selectedDevice == livingRoom)
        #expect(state.discoveryState == .idle)
    }

    @Test func discoveryExposesFailureWithoutDiscardingDevices() async {
        let state = AppState(deviceDiscovery: StubDeviceDiscovery(result: .failure(.discovery)))

        await state.discoverDevices()

        #expect(state.devices == [.placeholder])
        #expect(state.discoveryState == .failed(TestFailure.discovery.localizedDescription))
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

private struct StubDeviceDiscovery: DeviceDiscovering {
    let result: Result<[RemoteDevice], TestFailure>

    func discover() async throws -> [RemoteDevice] {
        try result.get()
    }
}

private enum TestFailure: Error {
    case command
    case discovery
}
