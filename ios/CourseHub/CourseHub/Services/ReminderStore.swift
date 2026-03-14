import Foundation

final class ReminderStore {
    static let shared = ReminderStore()
    private let key = "reminder_preferences"
    private init() {}

    func loadAll() -> [String: ReminderPreference] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let prefs = try? JSONDecoder().decode([ReminderPreference].self, from: data) else {
            return [:]
        }
        return Dictionary(prefs.map { ($0.dateId, $0) }, uniquingKeysWith: { _, new in new })
    }

    func save(_ preferences: [String: ReminderPreference]) {
        let array = Array(preferences.values)
        if let data = try? JSONEncoder().encode(array) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func getPreference(dateId: String) -> ReminderPreference? {
        loadAll()[dateId]
    }

    func setPreference(_ pref: ReminderPreference) {
        var all = loadAll()
        all[pref.dateId] = pref
        save(all)
    }
}
