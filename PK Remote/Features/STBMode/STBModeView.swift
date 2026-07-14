import SwiftUI

struct STBModeView: View {
    let appState: AppState

    private let actions: [(RemoteCommand, String, String)] = [
        (.search, "Search", "magnifyingglass"),
        (.view, "View", "rectangle.grid.2x2"),
        (.sort, "Sort", "arrow.up.arrow.down"),
        (.favorites, "Favorites", "star.fill")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Text(appState.selectedDevice?.name ?? "No device").font(.title2.bold()).frame(maxWidth: .infinity, alignment: .leading)
                    if !appState.isSelectedDevicePaired {
                        Label(
                            "Pair this TV from Devices to enable STB controls.",
                            systemImage: "lock.fill"
                        )
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(actions, id: \.0) { command, title, icon in
                            Button { send(command) } label: {
                                VStack(spacing: 10) {
                                    Image(systemName: icon).font(.title2)
                                    Text(title).font(.headline)
                                }
                                .frame(maxWidth: .infinity, minHeight: 100)
                                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
                            }
                            .buttonStyle(RemotePressedButtonStyle(prominence: false))
                            .accessibilityLabel(command.accessibilityLabel)
                        }
                    }
                    .disabled(!appState.isSelectedDevicePaired)
                    DPadView(action: send)
                        .disabled(!appState.isSelectedDevicePaired)
                    MediaControlsView(action: send)
                        .disabled(!appState.isSelectedDevicePaired)
                    if let commandError = appState.commandError {
                        Label(commandError, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityLabel("Remote error: \(commandError)")
                    }
                    Text("Last action: \(appState.lastActionDescription)").font(.footnote).foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("STB Mode")
        }
    }

    private func send(_ command: RemoteCommand) {
        Task { await appState.send(command) }
    }
}

#Preview("Light") { STBModeView(appState: .preview) }
#Preview("Dark") { STBModeView(appState: .preview).preferredColorScheme(.dark) }
