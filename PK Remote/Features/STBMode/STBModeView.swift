import SwiftUI

struct STBModeView: View {
    @State private var lastCommand = "Ready"

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
                    Text("PKD").font(.title2.bold()).frame(maxWidth: .infinity, alignment: .leading)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(actions, id: \.0) { command, title, icon in
                            Button { lastCommand = command.accessibilityLabel } label: {
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
                    DPadView { lastCommand = $0.accessibilityLabel }
                    MediaControlsView { lastCommand = $0.accessibilityLabel }
                    Text("Last action: \(lastCommand)").font(.footnote).foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("STB Mode")
        }
    }
}

#Preview("Light") { STBModeView() }
#Preview("Dark") { STBModeView().preferredColorScheme(.dark) }
