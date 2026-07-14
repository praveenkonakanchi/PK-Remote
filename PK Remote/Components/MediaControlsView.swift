import SwiftUI

struct MediaControlsView: View {
    var action: (RemoteCommand) -> Void = { _ in }

    var body: some View {
        HStack(spacing: 10) {
            RemoteButton(.rewind, systemImage: "backward.fill", action: action)
            RemoteButton(.playPause, systemImage: "playpause.fill", prominence: true, action: action)
            RemoteButton(.fastForward, systemImage: "forward.fill", action: action)
        }
    }
}

#Preview { MediaControlsView().padding() }
