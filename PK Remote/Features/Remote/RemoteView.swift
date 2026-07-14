import SwiftUI

struct RemoteView: View {
    let appState: AppState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    deviceHeader
                    HStack(spacing: 10) {
                        RemoteButton(.power, systemImage: "power", action: handle)
                        RemoteButton(.home, systemImage: "house.fill", action: handle)
                        RemoteButton(.back, systemImage: "arrow.uturn.backward", action: handle)
                    }
                    DPadView(action: handle)
                    volumeControls
                    NumberPadView(action: handle)
                    MediaControlsView(action: handle)
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
            Label("Available", systemImage: "circle.fill").font(.caption).foregroundStyle(.green)
        }
        .padding().background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
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
