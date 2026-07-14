import SwiftUI

struct RemoteView: View {
    let appState: AppState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    deviceHeader
                    if !appState.isSelectedDevicePaired {
                        Label(
                            "Pair this TV from Devices to enable remote controls.",
                            systemImage: "lock.fill"
                        )
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    HStack(spacing: 10) {
                        RemoteButton(.power, systemImage: "power", action: handle)
                        RemoteButton(.home, systemImage: "house.fill", action: handle)
                        RemoteButton(.back, systemImage: "arrow.uturn.backward", action: handle)
                    }
                    .disabled(!appState.isSelectedDevicePaired)
                    DPadView(action: handle)
                        .disabled(!appState.isSelectedDevicePaired)
                    volumeControls
                        .disabled(!appState.isSelectedDevicePaired)
                    NumberPadView(action: handle)
                        .disabled(!appState.isSelectedDevicePaired)
                    MediaControlsView(action: handle)
                        .disabled(!appState.isSelectedDevicePaired)
                    if let commandError = appState.commandError {
                        Label(commandError, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityLabel("Remote error: \(commandError)")
                    }
                    Text("Last action: \(appState.lastActionDescription)")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("Remote")
        }
    }

    private var deviceHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(appState.selectedDevice?.name ?? "No device").font(.title2.bold())
                Text(appState.selectedDevice?.kind ?? "Select a device").foregroundStyle(.secondary)
            }
            Spacer()
            pairingStatus
        }
        .padding().background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    private var pairingStatus: some View {
        if let device = appState.selectedDevice {
            let isPaired = appState.pairingState(for: device) == .paired
            Label(
                isPaired ? "Paired" : "Not paired",
                systemImage: isPaired ? "checkmark.shield.fill" : "exclamationmark.circle.fill"
            )
            .font(.caption)
            .foregroundStyle(isPaired ? .green : .orange)
        } else {
            Label("No device", systemImage: "tv.slash")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var volumeControls: some View {
        HStack(spacing: 10) {
            RemoteButton(.volumeDown, systemImage: "speaker.minus.fill", action: handle)
            RemoteButton(.mute, systemImage: "speaker.slash.fill", action: handle)
            RemoteButton(.volumeUp, systemImage: "speaker.plus.fill", action: handle)
        }
    }

    private func handle(_ command: RemoteCommand) {
        Task { await appState.send(command) }
    }
}

#Preview("Light") { RemoteView(appState: .preview) }
#Preview("Dark") { RemoteView(appState: .preview).preferredColorScheme(.dark) }
