import SwiftUI

struct NumberPadView: View {
    var action: (RemoteCommand) -> Void = { _ in }

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
            ForEach(1...9, id: \.self) { number in digit(number) }
            Color.clear.frame(height: 52).accessibilityHidden(true)
            digit(0)
        }
    }

    private func digit(_ number: Int) -> some View {
        RemoteButton(.digit(number), title: String(number), action: action)
    }
}

#Preview { NumberPadView().padding() }
