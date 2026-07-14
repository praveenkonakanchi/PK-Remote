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

    private let commandHandler: any RemoteCommandHandling
    private let deviceDiscovery: any DeviceDiscovering

    init(
        devices: [RemoteDevice] = [],
        selectedDeviceID: RemoteDevice.ID? = nil,
        commandHandler: (any RemoteCommandHandling)? = nil,
        deviceDiscovery: (any DeviceDiscovering)? = nil
    ) {
        self.devices = devices
        self.selectedDeviceID = selectedDeviceID
        self.commandHandler = commandHandler ?? LocalRemoteCommandHandler()
        self.deviceDiscovery = deviceDiscovery ?? BonjourDeviceDiscovery()
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
            deviceDiscovery: PlaceholderDeviceDiscovery()
        )
    }
}
