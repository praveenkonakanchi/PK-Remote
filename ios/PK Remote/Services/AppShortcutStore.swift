import Foundation

protocol AppShortcutStoring {
    func load() -> [RemoteAppShortcut]?
    func save(_ shortcuts: [RemoteAppShortcut])
}

struct UserDefaultsAppShortcutStore: AppShortcutStoring {
    private let defaults: UserDefaults
    private let key: String

    init(
        defaults: UserDefaults = .standard,
        key: String = "remoteAppShortcuts.catalog.v2"
    ) {
        self.defaults = defaults
        self.key = key
    }

    func load() -> [RemoteAppShortcut]? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode([RemoteAppShortcut].self, from: data)
    }

    func save(_ shortcuts: [RemoteAppShortcut]) {
        guard let data = try? JSONEncoder().encode(shortcuts) else { return }
        defaults.set(data, forKey: key)
    }
}
