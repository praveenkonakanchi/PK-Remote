import SwiftUI

struct STBModeView: View {
    let appState: AppState

    private let actions: [(command: RemoteCommand, title: String, color: Color)] = [
        (.view, "View", .red),
        (.sort, "Sort", .green),
        (.favorites, "Favorites", .yellow),
        (.find, "Find", .blue)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    DPadView(action: send)
                        .disabled(!appState.isSelectedDevicePaired)
                    HStack(spacing: 10) {
                        RemoteButton(.back, title: "Back", action: send)
                        RemoteButton(.menu, title: "Settings", action: send)
                    }
                    .disabled(!appState.isSelectedDevicePaired)
                    HStack(spacing: 8) {
                        ForEach(actions, id: \.command) { action in
                            portalButton(action)
                        }
                    }
                    .disabled(!appState.isSelectedDevicePaired)
                    MediaControlsView(action: send)
                        .disabled(!appState.isSelectedDevicePaired)
                    if !appState.isSelectedDevicePaired {
                        Label(
                            "Pair this TV from Devices to enable STB controls.",
                            systemImage: "lock.fill"
                        )
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
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
            .navigationTitle("STB Mode")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func portalButton(
        _ action: (command: RemoteCommand, title: String, color: Color)
    ) -> some View {
        Button { send(action.command) } label: {
            HStack(spacing: 5) {
                Circle()
                    .fill(action.color)
                    .frame(width: 11, height: 11)
                Text(action.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(Color.primary)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(RemotePressedButtonStyle(prominence: false))
        .accessibilityLabel(action.command.accessibilityLabel)
    }

    private func send(_ command: RemoteCommand) {
        Task { await appState.send(command) }
    }
}

#Preview("Light") { STBModeView(appState: .preview) }
#Preview("Dark") { STBModeView(appState: .preview).preferredColorScheme(.dark) }
