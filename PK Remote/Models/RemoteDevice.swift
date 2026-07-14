import Foundation

struct RemoteDevice: Identifiable, Hashable, Sendable {
    enum Availability: String, Sendable {
        case available = "Available"
        case unavailable = "Unavailable"
    }

    let id: UUID
    var name: String
    var kind: String
    var availability: Availability

    init(
        id: UUID = UUID(),
        name: String,
        kind: String = "Google TV",
        availability: Availability = .available
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.availability = availability
    }

    static let placeholder = RemoteDevice(
        id: UUID(uuidString: "504B4400-0000-0000-0000-000000000001")!,
        name: "PKD"
    )
}
