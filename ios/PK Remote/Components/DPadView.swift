import SwiftUI

struct DPadView: View {
    var action: (RemoteCommand) -> Void = { _ in }

    var body: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow { spacer; button(.up, "chevron.up"); spacer }
            GridRow {
                button(.left, "chevron.left")
                RemoteButton(.select, title: "OK", prominence: true, action: action)
                button(.right, "chevron.right")
            }
            GridRow { spacer; button(.down, "chevron.down"); spacer }
        }
    }

    private var spacer: some View { Color.clear.frame(minHeight: 52).accessibilityHidden(true) }
    private func button(_ command: RemoteCommand, _ image: String) -> some View {
        RemoteButton(command, systemImage: image, action: action)
    }
}

#Preview { DPadView().padding() }
