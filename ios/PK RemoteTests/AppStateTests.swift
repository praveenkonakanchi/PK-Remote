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

    @Test func stbUtilityControlsPreserveSemanticCommands() {
        #expect(
            STBModeView.utilityActions
                == [.remote(.home), .remote(.back), .keyboard, .remote(.menu)]
        )
        #expect(RemoteCommand.menu != .openGoogleTVSettings)
    }

    @Test func verifiedCatalogContainsOnlyPhysicallyValidatedApps() {
        #expect(RemoteAppCatalogItem.verified.map(\.displayName) == [
            "YouTube", "Netflix", "Prime Video", "Hulu", "Peacock", "Pluto TV",
            "Apple TV", "Disney+", "Aha", "Max", "Tubi", "Play Store"
        ])
        #expect(!RemoteAppCatalogItem.verified.contains { $0.displayName == "STBEmu" })
        #expect(!RemoteAppCatalogItem.verified.contains { $0.displayName == "Willow" })
        #expect(!RemoteAppCatalogItem.verified.contains { $0.displayName == "ZEE5" })
    }

    @Test func firstLaunchPersistsTheConfiguredDefaults() {
        let store = MemoryAppShortcutStore()
        let state = AppState(appShortcutStore: store)

        #expect(state.appShortcuts == RemoteAppShortcut.defaults)
        #expect(state.appShortcuts.map(\.displayName) == [
            "YouTube", "Netflix", "Prime Video", "Aha"
        ])
        #expect(store.shortcuts == state.appShortcuts)
    }

    @Test func shortcutsCanBeAddedOnlyUpToEight() {
        let state = AppState(appShortcutStore: MemoryAppShortcutStore())

        for item in RemoteAppCatalogItem.verified
            .filter({ candidate in
                !state.appShortcuts.contains { $0.catalogID == candidate.id }
            })
            .prefix(4) {
            #expect(state.addAppShortcut(item.makeShortcut()))
        }
        #expect(state.appShortcuts.count == 8)
        #expect(!state.canAddAppShortcut)
        #expect(!state.addAppShortcut(testShortcut(9)))
        #expect(state.appShortcuts.count == 8)
    }

    @Test func defaultShortcutCanBeEditedAndRemoved() throws {
        let state = AppState(appShortcutStore: MemoryAppShortcutStore())
        var shortcut = try #require(state.appShortcuts.first)
        shortcut.displayName = "My YouTube"
        shortcut.icon = .system("play.rectangle.fill")

        #expect(state.updateAppShortcut(shortcut))
        #expect(state.appShortcuts.first?.displayName == "My YouTube")

        state.removeAppShortcut(id: shortcut.id)
        #expect(!state.appShortcuts.contains { $0.id == shortcut.id })
    }

    @Test func shortcutOrderPersistsAcrossAppStateRestoration() throws {
        let store = MemoryAppShortcutStore()
        let firstState = AppState(appShortcutStore: store)
        let lastShortcut = try #require(firstState.appShortcuts.last)

        firstState.moveAppShortcut(id: lastShortcut.id, by: -3)
        let restoredState = AppState(appShortcutStore: store)

        #expect(restoredState.appShortcuts.map(\.id) == firstState.appShortcuts.map(\.id))
        #expect(restoredState.appShortcuts.first?.displayName == "Aha")
    }

    @Test func usedCatalogAppsDisappearAndReturnImmediately() throws {
        let state = AppState(appShortcutStore: MemoryAppShortcutStore())
        let hulu = try #require(
            RemoteAppCatalogItem.verified.first { $0.id == "hulu" }
        )

        #expect(state.addAppShortcut(hulu.makeShortcut()))
        #expect(!state.availableAppCatalogItems().contains { $0.id == hulu.id })

        let shortcut = try #require(state.appShortcuts.last)
        state.removeAppShortcut(id: shortcut.id)
        #expect(state.availableAppCatalogItems().contains { $0.id == hulu.id })
    }

    @Test func duplicateCatalogAndCustomIdentifiersAreRejected() throws {
        let state = AppState(appShortcutStore: MemoryAppShortcutStore())
        let youtube = try #require(RemoteAppCatalogItem.verified.first)

        #expect(!state.addAppShortcut(youtube.makeShortcut()))
        #expect(!state.addAppShortcut(RemoteAppShortcut(
            displayName: "YouTube duplicate",
            launchIdentifier: "  HTTPS://WWW.YOUTUBE.COM/  ",
            icon: .initials("Y")
        )))
        #expect(state.appShortcuts.count == 4)
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

    @Test func forgetPairingStopsTransportAndClearsCredential() async {
        let handler = PairingRejectedCommandHandler()
        let credentials = RecordingPairingCredentials(pairedDeviceIDs: [RemoteDevice.placeholder.id])
        let state = AppState(
            devices: [.placeholder],
            selectedDeviceID: RemoteDevice.placeholder.id,
            commandHandler: handler,
            pairingCredentials: credentials
        )

        await state.forgetPairing(for: .placeholder)

        #expect(state.pairingState(for: .placeholder) == .unpaired)
        #expect(await handler.stoppedDeviceIDs == [RemoteDevice.placeholder.id])
        #expect(credentials.removedDeviceIDs == [RemoteDevice.placeholder.id])
    }

    @Test func certificateRejectionInvalidatesPairingAndAllowsPairAgain() async {
        let handler = PairingRejectedCommandHandler()
        let pairing = RecordingPairingService()
        let credentials = RecordingPairingCredentials(pairedDeviceIDs: [RemoteDevice.placeholder.id])
        let state = AppState(
            devices: [.placeholder],
            selectedDeviceID: RemoteDevice.placeholder.id,
            commandHandler: handler,
            pairingService: pairing,
            pairingCredentials: credentials
        )

        await state.send(.home)

        let message = "Pairing is no longer valid because the TV rejected this app's certificate. Pair again to continue."
        #expect(state.pairingState(for: .placeholder) == .invalidated(message))
        #expect(!state.isSelectedDevicePaired)
        #expect(credentials.removedDeviceIDs == [RemoteDevice.placeholder.id])
        #expect(await handler.stoppedDeviceIDs == [RemoteDevice.placeholder.id])

        await state.requestPairingCode(for: .placeholder)
        #expect(state.pairingState(for: .placeholder) == .awaitingCode)
    }

    private func settle() async {
        for _ in 0..<10 { await Task.yield() }
    }

    private func testShortcut(_ index: Int) -> RemoteAppShortcut {
        RemoteAppShortcut(
            displayName: "App \(index)",
            launchIdentifier: "https://example.com/app/\(index)",
            icon: .initials("A")
        )
    }
}

@MainActor
private final class MemoryAppShortcutStore: AppShortcutStoring {
    var shortcuts: [RemoteAppShortcut]?

    func load() -> [RemoteAppShortcut]? { shortcuts }

    func save(_ shortcuts: [RemoteAppShortcut]) {
        self.shortcuts = shortcuts
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

private actor PairingRejectedCommandHandler: RemoteCommandHandling {
    private(set) var stoppedDeviceIDs: [RemoteDevice.ID] = []

    func send(_ command: RemoteCommand, to device: RemoteDevice) async throws {
        throw RemoteCommandTransportError.pairingRejected
    }

    func stopSession(for device: RemoteDevice) async {
        let deviceID = await device.id
        stoppedDeviceIDs.append(deviceID)
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

    func removePairing(for deviceID: RemoteDevice.ID) throws {}
}

private final class RecordingPairingCredentials: PairingCredentialChecking, @unchecked Sendable {
    private let lock = NSLock()
    private var pairedDeviceIDs: Set<RemoteDevice.ID>
    private var removedIDs: [RemoteDevice.ID] = []

    init(pairedDeviceIDs: Set<RemoteDevice.ID>) {
        self.pairedDeviceIDs = pairedDeviceIDs
    }

    var removedDeviceIDs: [RemoteDevice.ID] {
        lock.withLock { removedIDs }
    }

    func isPaired(deviceID: RemoteDevice.ID) -> Bool {
        lock.withLock { pairedDeviceIDs.contains(deviceID) }
    }

    func removePairing(for deviceID: RemoteDevice.ID) throws {
        lock.withLock {
            pairedDeviceIDs.remove(deviceID)
            removedIDs.append(deviceID)
        }
    }
}
