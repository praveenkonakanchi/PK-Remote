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
        devices: [RemoteDevice] = [.placeholder],
        selectedDeviceID: RemoteDevice.ID? = RemoteDevice.placeholder.id,
        commandHandler: any RemoteCommandHandling = LocalRemoteCommandHandler(),
        deviceDiscovery: any DeviceDiscovering = PlaceholderDeviceDiscovery()
    ) {
        self.devices = devices
        self.selectedDeviceID = selectedDeviceID
        self.commandHandler = commandHandler
        self.deviceDiscovery = deviceDiscovery
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

    func discoverDevices() async {
        discoveryState = .searching
        do {
            devices = try await deviceDiscovery.discover()
            if !devices.contains(where: { $0.id == selectedDeviceID }) {
                selectedDeviceID = devices.first?.id
            }
            discoveryState = .idle
        } catch {
            discoveryState = .failed(error.localizedDescription)
        }
    }
}
