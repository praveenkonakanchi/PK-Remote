import Foundation

nonisolated struct RemoteAppShortcut: Codable, Equatable, Identifiable, Sendable {
    enum Icon: Codable, Equatable, Sendable {
        case initials(String)
        case system(String)
    }

    let id: UUID
    var catalogID: String?
    var displayName: String
    var launchIdentifier: String
    var icon: Icon

    init(
        id: UUID = UUID(),
        catalogID: String? = nil,
        displayName: String,
        launchIdentifier: String,
        icon: Icon
    ) {
        self.id = id
        self.catalogID = catalogID
        self.displayName = displayName
        self.launchIdentifier = launchIdentifier
        self.icon = icon
    }

    static let defaults: [RemoteAppShortcut] = [
        RemoteAppShortcut(
            catalogID: "youtube",
            displayName: "YouTube",
            launchIdentifier: "https://www.youtube.com/",
            icon: .initials("Y")
        ),
        RemoteAppShortcut(
            catalogID: "netflix",
            displayName: "Netflix",
            launchIdentifier: "https://www.netflix.com/home",
            icon: .initials("N")
        ),
        RemoteAppShortcut(
            catalogID: "prime-video",
            displayName: "Prime Video",
            launchIdentifier: "https://app.primevideo.com",
            icon: .initials("P")
        ),
        RemoteAppShortcut(
            catalogID: "aha",
            displayName: "Aha",
            launchIdentifier: "https://www.aha.video/tab/home",
            icon: .initials("A")
        )
    ]
}

nonisolated struct RemoteAppCatalogItem: Equatable, Identifiable, Sendable {
    let id: String
    let displayName: String
    let launchIdentifier: String
    let icon: RemoteAppShortcut.Icon

    func makeShortcut(id shortcutID: UUID = UUID()) -> RemoteAppShortcut {
        RemoteAppShortcut(
            id: shortcutID,
            catalogID: id,
            displayName: displayName,
            launchIdentifier: launchIdentifier,
            icon: icon
        )
    }

    static let verified: [RemoteAppCatalogItem] = [
        item("youtube", "YouTube", "https://www.youtube.com/", "Y"),
        item("netflix", "Netflix", "https://www.netflix.com/home", "N"),
        item("prime-video", "Prime Video", "https://app.primevideo.com", "P"),
        item("hulu", "Hulu", "https://www.hulu.com/", "H"),
        item("peacock", "Peacock", "https://www.peacocktv.com/deeplink", "P"),
        item("pluto-tv", "Pluto TV", "https://pluto.tv/", "P"),
        item("apple-tv", "Apple TV", "https://tv.apple.com/", "A"),
        item("disney-plus", "Disney+", "https://www.disneyplus.com/", "D"),
        item("aha", "Aha", "https://www.aha.video/tab/home", "A"),
        item("max", "Max", "https://play.max.com/", "M"),
        item("tubi", "Tubi", "https://link.tubi.tv/", "T"),
        item("play-store", "Play Store", "https://play.google.com/store", "P")
    ]

    private static func item(
        _ id: String,
        _ name: String,
        _ launchIdentifier: String,
        _ initial: String
    ) -> RemoteAppCatalogItem {
        RemoteAppCatalogItem(
            id: id,
            displayName: name,
            launchIdentifier: launchIdentifier,
            icon: .initials(initial)
        )
    }
}
