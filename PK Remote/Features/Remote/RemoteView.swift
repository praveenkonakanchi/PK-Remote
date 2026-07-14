import SwiftUI

struct RemoteView: View {
    let appState: AppState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
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
                    MediaControlsView(action: handle)
                        .disabled(!appState.isSelectedDevicePaired)
                    NumberPadView(action: handle)
                        .disabled(!appState.isSelectedDevicePaired)
                    if let commandError = appState.commandError {
                        Label(commandError, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityLabel("Remote error: \(commandError)")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Remote")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var deviceHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "tv.fill")
                .foregroundStyle(.indigo)
            Text(appState.selectedDevice?.name ?? "No device")
                .font(.headline)
                .lineLimit(1)
            Spacer()
            pairingStatus
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
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
