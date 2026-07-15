import SwiftUI

struct RemoteButton: View {
    let command: RemoteCommand
    let systemImage: String?
    let title: String?
    var prominence = false
    var action: (RemoteCommand) -> Void = { _ in }

    init(
        _ command: RemoteCommand,
        systemImage: String? = nil,
        title: String? = nil,
        prominence: Bool = false,
        action: @escaping (RemoteCommand) -> Void = { _ in }
    ) {
        self.command = command
        self.systemImage = systemImage
        self.title = title
        self.prominence = prominence
        self.action = action
    }

    var body: some View {
        Button { action(command) } label: {
            Group {
                if let systemImage { Image(systemName: systemImage).font(.title3.weight(.semibold)) }
                else { Text(title ?? command.accessibilityLabel).font(.headline) }
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(prominence ? Color.white : Color.primary)
            .background(prominence ? Color.indigo : Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(RemotePressedButtonStyle(prominence: prominence))
        .accessibilityLabel(command.accessibilityLabel)
    }
}

struct RemotePressedButtonStyle: ButtonStyle {
    let prominence: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .brightness(configuration.isPressed ? (prominence ? 0.12 : -0.12) : 0)
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        Color.indigo.opacity(configuration.isPressed ? 0.9 : 0),
                        lineWidth: 3
                    )
            }
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

#Preview { RemoteButton(.home, systemImage: "house.fill") }
