import SwiftUI

struct DevicesView: View {
    let appState: AppState

    var body: some View {
        NavigationStack {
            List {
                Section("Google TV") {
                    ForEach(appState.devices) { device in
                        Button { appState.select(device) } label: {
                            deviceRow(device)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .overlay {
                emptyState
            }
            .navigationTitle("Devices")
            .toolbar {
                Button {
                    appState.startDiscovery()
                } label: {
                    if appState.discoveryState == .searching { ProgressView() }
                    else { Label("Refresh devices", systemImage: "arrow.clockwise") }
                }
                .disabled(appState.discoveryState == .searching)
            }
            .task {
                if appState.devices.isEmpty && appState.discoveryState == .idle {
                    appState.startDiscovery()
                }
            }
            .onDisappear { appState.stopDiscovery() }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if appState.devices.isEmpty {
            switch appState.discoveryState {
            case .searching:
                ContentUnavailableView {
                    Label("Searching", systemImage: "antenna.radiowaves.left.and.right")
                } description: {
                    Text("Looking for Google TV devices on your local network.")
                } actions: {
                    ProgressView()
                }
            case .failed(let message):
                ContentUnavailableView("Discovery Failed", systemImage: "exclamationmark.triangle", description: Text(message))
            case .idle:
                ContentUnavailableView("No Devices", systemImage: "tv.slash", description: Text("Make sure your TV is on and connected to the same Wi-Fi network."))
            }
        }
    }

    private func deviceRow(_ device: RemoteDevice) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "tv.fill")
                .font(.title2)
                .foregroundStyle(.indigo)
                .frame(width: 44, height: 44)
                .background(.indigo.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading) {
                Text(device.name).font(.headline)
                Text(device.kind).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            if appState.selectedDeviceID == device.id {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.indigo)
            } else {
                Image(systemName: "circle.fill")
                    .font(.caption)
                    .foregroundStyle(device.availability == .available ? .green : .secondary)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(device.name), \(device.kind), \(device.availability.rawValue)")
    }
}

#Preview { DevicesView(appState: .preview) }
