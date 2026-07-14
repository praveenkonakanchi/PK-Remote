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
        let state = AppState(
            devices: [.placeholder],
            selectedDeviceID: RemoteDevice.placeholder.id,
            commandHandler: handler,
            pairingCredentials: StubPairingCredentials(pairedDeviceIDs: [RemoteDevice.placeholder.id])
        )

        await state.send(.volumeUp)

        #expect(await handler.commands == [.volumeUp])
        #expect(state.lastCommand == .volumeUp)
        #expect(state.lastActionDescription == "Volume up")
        #expect(state.commandError == nil)
    }

    @Test func preservesLastCommandWhenSendingFails() async {
        let state = AppState(
            devices: [.placeholder],
            selectedDeviceID: RemoteDevice.placeholder.id,
            commandHandler: FailingCommandHandler(),
            pairingCredentials: StubPairingCredentials(pairedDeviceIDs: [RemoteDevice.placeholder.id])
        )

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

    @Test func discoveryPrefersPersistentlyPairedDevice() async {
        let unpaired = RemoteDevice(name: "My bedroom TV")
        let paired = RemoteDevice(name: "peekay TV")
        let discovery = StubDeviceDiscovery()
        let state = AppState(
            deviceDiscovery: discovery,
            pairingCredentials: StubPairingCredentials(pairedDeviceIDs: [paired.id])
        )

        state.startDiscovery()
        discovery.send(.success([unpaired, paired]))
        await settle()

        #expect(state.selectedDevice == paired)
        #expect(state.isSelectedDevicePaired)
    }

    @Test func commandIsRejectedBeforeTransportForUnpairedDevice() async {
        let handler = RecordingCommandHandler()
        let state = AppState(
            devices: [.placeholder],
            selectedDeviceID: RemoteDevice.placeholder.id,
            commandHandler: handler,
            pairingCredentials: StubPairingCredentials(pairedDeviceIDs: [])
        )

        await state.send(.home)

        #expect(await handler.commands.isEmpty)
        #expect(state.commandError == "Pair this TV from Devices before using the remote.")
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

    @Test func pairingTransitionsThroughCodeRequestToPaired() async {
        let pairing = RecordingPairingService()
        let state = AppState(devices: [.placeholder], pairingService: pairing)

        await state.requestPairingCode(for: .placeholder)
        #expect(state.pairingState(for: .placeholder) == .awaitingCode)

        await state.submitPairingCode(" 61a2c9\n", for: .placeholder)
        #expect(state.pairingState(for: .placeholder) == .paired)
        #expect(await pairing.submittedCodes == ["61A2C9"])
    }

    @Test func restoresPairedStateFromPersistedCredential() {
        let state = AppState(
            devices: [.placeholder],
            pairingCredentials: StubPairingCredentials(pairedDeviceIDs: [RemoteDevice.placeholder.id])
        )

        #expect(state.pairingState(for: .placeholder) == .paired)
    }

    @Test func differentDeviceRemainsUnpaired() {
        let other = RemoteDevice(name: "Other TV")
        let state = AppState(
            devices: [.placeholder, other],
            pairingCredentials: StubPairingCredentials(pairedDeviceIDs: [RemoteDevice.placeholder.id])
        )

        #expect(state.pairingState(for: .placeholder) == .paired)
        #expect(state.pairingState(for: other) == .unpaired)
    }

    @Test func pairingRejectsInvalidCodeBeforeCallingService() async {
        let pairing = RecordingPairingService()
        let state = AppState(devices: [.placeholder], pairingService: pairing)

        await state.submitPairingCode("12GZ", for: .placeholder)

        #expect(state.pairingState(for: .placeholder) == .failed("Enter the 6-character code shown on your TV."))
        #expect(await pairing.submittedCodes.isEmpty)
    }

    @Test func pairingFailureIsExposedAndCanBeCancelled() async {
        let pairing = FailingPairingService()
        let state = AppState(devices: [.placeholder], pairingService: pairing)

        await state.requestPairingCode(for: .placeholder)
        #expect(state.pairingState(for: .placeholder) == .failed(TestFailure.pairing.localizedDescription))

        await state.cancelPairing(for: .placeholder)
        #expect(state.pairingState(for: .placeholder) == .unpaired)
    }

    @Test func productionPairingRequiresDiscoveredServiceMetadata() async {
        let state = AppState(devices: [.placeholder])

        await state.requestPairingCode(for: .placeholder)

        #expect(
            state.pairingState(for: .placeholder)
                == .failed("The TV pairing service could not be resolved. Refresh Devices and try again.")
        )
    }

    private func settle() async {
        for _ in 0..<10 { await Task.yield() }
    }
}

private actor RecordingCommandHandler: RemoteCommandHandling {
    private(set) var commands: [RemoteCommand] = []

    func send(_ command: RemoteCommand, to device: RemoteDevice) async throws {
        commands.append(command)
    }
}

private struct FailingCommandHandler: RemoteCommandHandling {
    func send(_ command: RemoteCommand, to device: RemoteDevice) async throws {
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
    case pairing
}

private actor RecordingPairingService: DevicePairingService {
    private(set) var submittedCodes: [String] = []

    func requestPairingCode(for device: RemoteDevice) async throws {}

    func pair(_ device: RemoteDevice, using code: String) async throws {
        submittedCodes.append(code)
    }

    func cancelPairing(for device: RemoteDevice) async {}
}

private struct FailingPairingService: DevicePairingService {
    func requestPairingCode(for device: RemoteDevice) async throws {
        throw TestFailure.pairing
    }

    func pair(_ device: RemoteDevice, using code: String) async throws {
        throw TestFailure.pairing
    }

    func cancelPairing(for device: RemoteDevice) async {}
}

private struct StubPairingCredentials: PairingCredentialChecking {
    let pairedDeviceIDs: Set<RemoteDevice.ID>

    func isPaired(deviceID: RemoteDevice.ID) -> Bool {
        pairedDeviceIDs.contains(deviceID)
    }
}
