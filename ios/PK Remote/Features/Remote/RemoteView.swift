import SwiftUI

struct RemoteView: View {
    let appState: AppState
    @State private var commandError: String?
    @State private var errorDismissTask: Task<Void, Never>?
    @State private var isVisible = false

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
                    if let commandError {
                        transientError(commandError)
                    }
                    HStack(spacing: 10) {
                        RemoteButton(.power, systemImage: "power", action: handle)
                        RemoteButton(.home, systemImage: "house.fill", action: handle)
                        RemoteButton(.back, systemImage: "arrow.uturn.backward", action: handle)
                        RemoteButton(
                            .openGoogleTVSettings,
                            systemImage: "gearshape.fill",
                            action: handle
                        )
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
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Remote")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { isVisible = true }
            .onDisappear {
                isVisible = false
                errorDismissTask?.cancel()
                commandError = nil
            }
        }
    }

    private func transientError(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.footnote)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("Remote error: \(message)")
            .transition(.opacity.combined(with: .move(edge: .top)))
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
        Task {
            let message = await appState.send(command)
            guard isVisible else { return }
            showTransientError(message)
        }
    }

    private func showTransientError(_ message: String?) {
        errorDismissTask?.cancel()
        withAnimation { commandError = message }
        guard let message else { return }
        errorDismissTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled, commandError == message else { return }
            withAnimation { commandError = nil }
        }
    }
}

#Preview("Light") { RemoteView(appState: .preview) }
#Preview("Dark") { RemoteView(appState: .preview).preferredColorScheme(.dark) }
