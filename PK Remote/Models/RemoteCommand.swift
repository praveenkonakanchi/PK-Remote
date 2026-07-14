import Foundation

enum RemoteCommand: Hashable, Sendable {
    case power, home, back, menu
    case up, down, left, right, select
    case volumeUp, volumeDown, mute
    case digit(Int)
    case previous, playPause, next, rewind, fastForward
    case view, sort, favorites, find
    case text(String)

    var accessibilityLabel: String {
        switch self {
        case .power: "Power"
        case .home: "Home"
        case .back: "Back"
        case .menu: "Settings"
        case .up: "Navigate up"
        case .down: "Navigate down"
        case .left: "Navigate left"
        case .right: "Navigate right"
        case .select: "Select"
        case .volumeUp: "Volume up"
        case .volumeDown: "Volume down"
        case .mute: "Mute"
        case .digit(let number): "Number \(number)"
        case .previous: "Previous"
        case .playPause: "Play or pause"
        case .next: "Next"
        case .rewind: "Rewind"
        case .fastForward: "Fast forward"
        case .view: "View"
        case .sort: "Sort"
        case .favorites: "Favorites"
        case .find: "Find"
        case .text: "Enter text"
        }
    }
}
