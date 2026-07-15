enum DevicePairingState: Equatable, Sendable {
    case unpaired
    case requestingCode
    case awaitingCode
    case pairing
    case paired
    case failed(String)

    var isBusy: Bool {
        self == .requestingCode || self == .pairing
    }
}
