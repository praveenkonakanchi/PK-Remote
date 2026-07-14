import Foundation

struct RemoteDevice: Identifiable, Hashable, Sendable {
    enum Availability: String, Sendable {
        case available = "Available"
        case unavailable = "Unavailable"
    }

    let id: String
    var name: String
    var kind: String
    var availability: Availability
    var serviceType: String?
    var serviceDomain: String?

    init(
        id: String? = nil,
        name: String,
        kind: String = "Google TV",
        availability: Availability = .available,
        serviceType: String? = nil,
        serviceDomain: String? = nil
    ) {
        self.id = id ?? Self.makeID(name: name, type: serviceType, domain: serviceDomain)
        self.name = name
        self.kind = kind
        self.availability = availability
        self.serviceType = serviceType
        self.serviceDomain = serviceDomain
    }

    static let placeholder = RemoteDevice(
        id: "placeholder-pkd",
        name: "PKD"
    )

    static func makeID(name: String, type: String?, domain: String?) -> String {
        [name, type ?? "", domain ?? ""]
            .joined(separator: "|")
            .lowercased()
    }
}
