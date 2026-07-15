import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    static let maximumAppShortcutCount = 8

    enum DiscoveryState: Equatable {
        case idle
        case searching
        case failed(String)
    }

    private(set) var devices: [RemoteDevice]
    var selectedDeviceID: RemoteDevice.ID?
    private(set) var discoveryState: DiscoveryState = .idle
    private(set) var lastCommand: RemoteCommand?
    private(set) var commandError: String?
    private(set) var pairingStates: [RemoteDevice.ID: DevicePairingState] = [:]
    private(set) var appShortcuts: [RemoteAppShortcut]

    private let commandHandler: any RemoteCommandHandling
    private let deviceDiscovery: any DeviceDiscovering
    private let pairingService: any DevicePairingService
    private let pairingCredentials: any PairingCredentialChecking
    private let appShortcutStore: any AppShortcutStoring

    init(
        devices: [RemoteDevice] = [],
        selectedDeviceID: RemoteDevice.ID? = nil,
        commandHandler: (any RemoteCommandHandling)? = nil,
        deviceDiscovery: (any DeviceDiscovering)? = nil,
        pairingService: (any DevicePairingService)? = nil,
        pairingCredentials: (any PairingCredentialChecking)? = nil,
        appShortcutStore: (any AppShortcutStoring)? = nil
    ) {
        let shortcutStore = appShortcutStore ?? UserDefaultsAppShortcutStore()
        let storedShortcuts = shortcutStore.load()
        let initialShortcuts = Array(
            (storedShortcuts ?? RemoteAppShortcut.defaults)
                .prefix(Self.maximumAppShortcutCount)
        )
        self.devices = devices
        self.selectedDeviceID = selectedDeviceID
        self.appShortcuts = initialShortcuts
        self.commandHandler = commandHandler ?? GoogleTVRemoteCommandService()
        self.deviceDiscovery = deviceDiscovery ?? BonjourDeviceDiscovery()
        self.pairingService = pairingService ?? GoogleTVPairingService()
        self.pairingCredentials = pairingCredentials ?? PairingCredentialStore()
        self.appShortcutStore = shortcutStore
        if storedShortcuts == nil {
            shortcutStore.save(initialShortcuts)
        }
    }

    var selectedDevice: RemoteDevice? {
        devices.first { $0.id == selectedDeviceID }
    }

    var lastActionDescription: String {
        lastCommand?.accessibilityLabel ?? "Ready"
    }

    var isSelectedDevicePaired: Bool {
        selectedDevice.map { pairingState(for: $0) == .paired } ?? false
    }

    var canAddAppShortcut: Bool {
        appShortcuts.count < Self.maximumAppShortcutCount
            && !availableAppCatalogItems().isEmpty
    }

    func availableAppCatalogItems(
        replacing shortcutID: RemoteAppShortcut.ID? = nil
    ) -> [RemoteAppCatalogItem] {
        let occupied = appShortcuts.filter { $0.id != shortcutID }
        return RemoteAppCatalogItem.verified.filter { item in
            !occupied.contains { Self.matches($0, catalogItem: item) }
        }
    }

    func select(_ device: RemoteDevice) {
        selectedDeviceID = device.id
    }

    func pairingState(for device: RemoteDevice) -> DevicePairingState {
        if let transientState = pairingStates[device.id] {
            return transientState
        }
        return pairingCredentials.isPaired(deviceID: device.id) ? .paired : .unpaired
    }

    func requestPairingCode(for device: RemoteDevice) async {
        pairingStates[device.id] = .requestingCode
        do {
            try await pairingService.requestPairingCode(for: device)
            pairingStates[device.id] = .awaitingCode
        } catch {
            pairingStates[device.id] = .failed(error.localizedDescription)
        }
    }

    func submitPairingCode(_ code: String, for device: RemoteDevice) async {
        let normalizedCode = code
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        let hexadecimalCharacters = CharacterSet(charactersIn: "0123456789ABCDEF")
        guard normalizedCode.count == 6,
              normalizedCode.unicodeScalars.allSatisfy(hexadecimalCharacters.contains) else {
            pairingStates[device.id] = .failed("Enter the 6-character code shown on your TV.")
            return
        }

        pairingStates[device.id] = .pairing
        do {
            try await pairingService.pair(device, using: normalizedCode)
            pairingStates[device.id] = .paired
        } catch {
            pairingStates[device.id] = .failed(error.localizedDescription)
        }
    }

    func cancelPairing(for device: RemoteDevice) async {
        await pairingService.cancelPairing(for: device)
        pairingStates[device.id] = pairingCredentials.isPaired(deviceID: device.id)
            ? .paired
            : .unpaired
    }

    func forgetPairing(for device: RemoteDevice) async {
        await pairingService.cancelPairing(for: device)
        await commandHandler.stopSession(for: device)
        do {
            try pairingCredentials.removePairing(for: device.id)
            pairingStates[device.id] = .unpaired
            commandError = nil
        } catch {
            pairingStates[device.id] = .failed(error.localizedDescription)
        }
    }

    func send(_ command: RemoteCommand) async {
        commandError = nil
        guard let selectedDevice else {
            commandError = "Select a TV before sending a command."
            return
        }
        guard pairingState(for: selectedDevice) == .paired else {
            commandError = "Pair this TV from Devices before using the remote."
            return
        }
        do {
            try await commandHandler.send(command, to: selectedDevice)
            lastCommand = command
        } catch {
            if case .launchApp(let identifier) = command,
               error.isAppLaunchRejected {
                let displayName = appShortcuts.first {
                    Self.normalizedIdentifier($0.launchIdentifier)
                        == Self.normalizedIdentifier(identifier)
                }?.displayName ?? "this app"
                commandError = "Couldn’t open \(displayName). Make sure the app is installed on your TV, then try again."
            } else {
                commandError = error.localizedDescription
            }
            if let invalidationMessage = error.pairingInvalidationMessage {
                await commandHandler.stopSession(for: selectedDevice)
                try? pairingCredentials.removePairing(for: selectedDevice.id)
                pairingStates[selectedDevice.id] = .invalidated(invalidationMessage)
            }
        }
    }

    @discardableResult
    func addAppShortcut(_ shortcut: RemoteAppShortcut) -> Bool {
        guard canAddAppShortcut,
              Self.isValid(shortcut),
              !containsDuplicate(of: shortcut) else { return false }
        appShortcuts.append(Self.normalized(shortcut))
        persistAppShortcuts()
        return true
    }

    @discardableResult
    func updateAppShortcut(_ shortcut: RemoteAppShortcut) -> Bool {
        guard Self.isValid(shortcut),
              let index = appShortcuts.firstIndex(where: { $0.id == shortcut.id }),
              !containsDuplicate(of: shortcut, excluding: shortcut.id) else {
            return false
        }
        appShortcuts[index] = Self.normalized(shortcut)
        persistAppShortcuts()
        return true
    }

    func removeAppShortcut(id: RemoteAppShortcut.ID) {
        appShortcuts.removeAll { $0.id == id }
        persistAppShortcuts()
    }

    func moveAppShortcut(id: RemoteAppShortcut.ID, by offset: Int) {
        guard let source = appShortcuts.firstIndex(where: { $0.id == id }) else { return }
        let destination = min(max(source + offset, 0), appShortcuts.count - 1)
        guard source != destination else { return }
        let shortcut = appShortcuts.remove(at: source)
        appShortcuts.insert(shortcut, at: destination)
        persistAppShortcuts()
    }

    func startDiscovery() {
        discoveryState = .searching
        deviceDiscovery.start { [weak self] result in
            Task { @MainActor [weak self] in
                self?.applyDiscoveryUpdate(result)
            }
        }
    }

    func stopDiscovery() {
        deviceDiscovery.stop()
        if discoveryState == .searching {
            discoveryState = .idle
        }
    }

    private func applyDiscoveryUpdate(_ result: Result<[RemoteDevice], Error>) {
        switch result {
        case .success(let discoveredDevices):
            devices = Self.deduplicated(discoveredDevices)
            if !devices.contains(where: { $0.id == selectedDeviceID }) {
                selectedDeviceID = devices.first(where: {
                    pairingCredentials.isPaired(deviceID: $0.id)
                })?.id ?? devices.first?.id
            }
            discoveryState = .idle
        case .failure(let error):
            discoveryState = .failed(error.localizedDescription)
        }
    }

    private static func deduplicated(_ devices: [RemoteDevice]) -> [RemoteDevice] {
        var seen = Set<RemoteDevice.ID>()
        return devices.filter { seen.insert($0.id).inserted }
    }

    private func persistAppShortcuts() {
        appShortcutStore.save(appShortcuts)
    }

    private func containsDuplicate(
        of shortcut: RemoteAppShortcut,
        excluding excludedID: RemoteAppShortcut.ID? = nil
    ) -> Bool {
        appShortcuts.contains { existing in
            existing.id != excludedID && Self.matches(existing, shortcut)
        }
    }

    private static func matches(
        _ lhs: RemoteAppShortcut,
        _ rhs: RemoteAppShortcut
    ) -> Bool {
        if let lhsCatalogID = lhs.catalogID,
           let rhsCatalogID = rhs.catalogID,
           lhsCatalogID == rhsCatalogID {
            return true
        }
        return normalizedIdentifier(lhs.launchIdentifier)
            == normalizedIdentifier(rhs.launchIdentifier)
    }

    private static func matches(
        _ shortcut: RemoteAppShortcut,
        catalogItem: RemoteAppCatalogItem
    ) -> Bool {
        shortcut.catalogID == catalogItem.id
            || normalizedIdentifier(shortcut.launchIdentifier)
                == normalizedIdentifier(catalogItem.launchIdentifier)
    }

    private static func normalizedIdentifier(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func isValid(_ shortcut: RemoteAppShortcut) -> Bool {
        !shortcut.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !shortcut.launchIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func normalized(_ shortcut: RemoteAppShortcut) -> RemoteAppShortcut {
        var shortcut = shortcut
        shortcut.displayName = shortcut.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        shortcut.launchIdentifier = shortcut.launchIdentifier
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return shortcut
    }

    static var preview: AppState {
        AppState(
            devices: [.placeholder],
            selectedDeviceID: RemoteDevice.placeholder.id,
            commandHandler: LocalRemoteCommandHandler(),
            deviceDiscovery: PlaceholderDeviceDiscovery(),
            pairingService: PreviewDevicePairingService()
        )
    }
}

private extension Error {
    var isAppLaunchRejected: Bool {
        guard let error = self as? RemoteCommandTransportError else { return false }
        if case .appLaunchRejected = error { return true }
        return false
    }

    var pairingInvalidationMessage: String? {
        guard let error = self as? RemoteCommandTransportError else { return nil }
        return switch error {
        case .certificateChanged:
            "Pairing is no longer valid because the TV certificate changed. Pair again to continue."
        case .pairingRejected:
            "Pairing is no longer valid because the TV rejected this app's certificate. Pair again to continue."
        case .notPaired:
            "No valid pairing credential exists for this TV. Pair again to continue."
        default:
            nil
        }
    }
}
