import Foundation

final class CustomReminderStore {
    static let shared = CustomReminderStore()
    private let key = "custom_reminders"
    private init() {}

    func loadAll() -> [ImportantDate] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let reminders = try? JSONDecoder().decode([ImportantDate].self, from: data) else {
            return []
        }
        return reminders
    }

    func save(_ reminders: [ImportantDate]) {
        if let data = try? JSONEncoder().encode(reminders) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func add(_ reminder: ImportantDate) {
        var all = loadAll()
        all.append(reminder)
        save(all)
    }

    func remove(id: String) {
        var all = loadAll()
        all.removeAll { $0.id == id }
        save(all)
    }

    func loadForClass(_ classId: String) -> [ImportantDate] {
        loadAll().filter { $0.classId == classId }
    }
}
