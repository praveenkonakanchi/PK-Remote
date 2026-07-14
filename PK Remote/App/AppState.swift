import Foundation
import Observation

@MainActor
@Observable
final class AppState {
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

    private let commandHandler: any RemoteCommandHandling
    private let deviceDiscovery: any DeviceDiscovering
    private let pairingService: any DevicePairingService

    init(
        devices: [RemoteDevice] = [],
        selectedDeviceID: RemoteDevice.ID? = nil,
        commandHandler: (any RemoteCommandHandling)? = nil,
        deviceDiscovery: (any DeviceDiscovering)? = nil,
        pairingService: (any DevicePairingService)? = nil
    ) {
        self.devices = devices
        self.selectedDeviceID = selectedDeviceID
        self.commandHandler = commandHandler ?? LocalRemoteCommandHandler()
        self.deviceDiscovery = deviceDiscovery ?? BonjourDeviceDiscovery()
        self.pairingService = pairingService ?? GoogleTVPairingService()
    }

    var selectedDevice: RemoteDevice? {
        devices.first { $0.id == selectedDeviceID }
    }

    var lastActionDescription: String {
        lastCommand?.accessibilityLabel ?? "Ready"
    }

    func select(_ device: RemoteDevice) {
        selectedDeviceID = device.id
    }

    func pairingState(for device: RemoteDevice) -> DevicePairingState {
        pairingStates[device.id] ?? .unpaired
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
        pairingStates[device.id] = .unpaired
    }

    func send(_ command: RemoteCommand) async {
        commandError = nil
        do {
            try await commandHandler.send(command)
            lastCommand = command
        } catch {
            commandError = error.localizedDescription
        }
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
                selectedDeviceID = devices.first?.id
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

    static var preview: AppState {
        AppState(
            devices: [.placeholder],
            selectedDeviceID: RemoteDevice.placeholder.id,
            deviceDiscovery: PlaceholderDeviceDiscovery(),
            pairingService: PreviewDevicePairingService()
        )
    }
}
