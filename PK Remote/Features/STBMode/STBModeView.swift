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
                            .buttonStyle(.plain)
                            .accessibilityLabel(command.accessibilityLabel)
                        }
                    }
                    DPadView(action: send)
                    MediaControlsView(action: send)
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

#Preview("Light") { STBModeView(appState: AppState()) }
#Preview("Dark") { STBModeView(appState: AppState()).preferredColorScheme(.dark) }
