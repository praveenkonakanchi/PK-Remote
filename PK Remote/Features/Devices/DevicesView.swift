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
                if appState.devices.isEmpty && appState.discoveryState == .idle {
                    ContentUnavailableView("No Devices", systemImage: "tv.slash", description: Text("Refresh to look for devices."))
                }
            }
            .navigationTitle("Devices")
            .toolbar {
                Button {
                    Task { await appState.discoverDevices() }
                } label: {
                    if appState.discoveryState == .searching { ProgressView() }
                    else { Label("Refresh devices", systemImage: "arrow.clockwise") }
                }
                .disabled(appState.discoveryState == .searching)
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

#Preview { DevicesView(appState: AppState()) }
