import SwiftUI

struct STBModeView: View {
    let appState: AppState
    @State private var isKeyboardPresented = false

    private let actions: [(command: RemoteCommand, title: String, color: Color)] = [
        (.view, "View", .red),
        (.sort, "Sort", .green),
        (.favorites, "Favorites", .yellow),
        (.find, "Find", .blue)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 50) {
                    DPadView(action: send)
                        .disabled(!appState.isSelectedDevicePaired)
                    HStack(spacing: 10) {
                        RemoteButton(.back, systemImage: "arrow.uturn.backward", action: send)
                        keyboardButton
                        RemoteButton(.menu, systemImage: "gearshape.fill", action: send)
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
            .sheet(isPresented: $isKeyboardPresented) {
                STBKeyboardSheet { text in
                    send(.text(text))
                }
            }
        }
    }

    private var keyboardButton: some View {
        Button { isKeyboardPresented = true } label: {
            Image(systemName: "keyboard")
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 52)
                .foregroundStyle(Color.primary)
                .background(
                    Color(.secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 16)
                )
        }
        .buttonStyle(RemotePressedButtonStyle(prominence: false))
        .accessibilityLabel("Keyboard")
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

private struct STBKeyboardSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    @State private var text = ""
    let onSend: (String) -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Select a text field on your TV, then enter text here.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                TextField("Enter text", text: $text, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .focused($isFocused)
                    .submitLabel(.send)
                    .onSubmit(sendText)
                Spacer()
            }
            .padding()
            .navigationTitle("Keyboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send", action: sendText)
                        .disabled(text.isEmpty)
                }
            }
            .onAppear { isFocused = true }
        }
        .presentationDetents([.medium])
    }

    private func sendText() {
        guard !text.isEmpty else { return }
        onSend(text)
        dismiss()
    }
}

#Preview("Light") { STBModeView(appState: .preview) }
#Preview("Dark") { STBModeView(appState: .preview).preferredColorScheme(.dark) }
