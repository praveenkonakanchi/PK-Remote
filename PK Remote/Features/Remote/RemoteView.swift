import SwiftUI

struct RemoteView: View {
    @State private var lastCommand = "Ready"

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
                    Text("Last action: \(lastCommand)")
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
                Text("PKD").font(.title2.bold())
                Text("Google TV").foregroundStyle(.secondary)
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

    private func handle(_ command: RemoteCommand) { lastCommand = command.accessibilityLabel }
}

#Preview("Light") { RemoteView() }
#Preview("Dark") { RemoteView().preferredColorScheme(.dark) }
