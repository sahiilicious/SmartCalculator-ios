import Foundation

/// Persists calculator history between launches.
protocol HistoryStoring {
    func load() -> [HistoryEntry]
    func save(_ entries: [HistoryEntry])
}

struct UserDefaultsHistoryStore: HistoryStoring {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [HistoryEntry] {
        guard let data = defaults.data(forKey: SettingsKeys.calculatorHistory) else { return [] }
        return (try? JSONDecoder().decode([HistoryEntry].self, from: data)) ?? []
    }

    func save(_ entries: [HistoryEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: SettingsKeys.calculatorHistory)
    }
}
