import Foundation

@Observable
class RemindersViewModel {
    var allDates: [ImportantDate] = []
    var reminders: [String: ReminderPreference] = [:]
    var isLoading = false
    var errorMessage: String?
    var permissionDenied = false

    var upcomingDates: [ImportantDate] {
        let now = Calendar.current.startOfDay(for: Date())
        return allDates
            .filter { ($0.parsedDate ?? .distantPast) >= now }
            .sorted { ($0.parsedDate ?? .distantPast) < ($1.parsedDate ?? .distantPast) }
    }

    var datesByMonth: [(String, [ImportantDate])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        var grouped: [String: [ImportantDate]] = [:]
        var order: [String] = []
        for date in upcomingDates {
            let key = date.parsedDate.map { formatter.string(from: $0) } ?? "Unknown"
            if grouped[key] == nil { order.append(key) }
            grouped[key, default: []].append(date)
        }
        return order.map { ($0, grouped[$0]!) }
    }

    @MainActor
    func loadDates() async {
        isLoading = true
        errorMessage = nil
        do {
            allDates = try await APIClient.shared.fetchImportantDates()
            reminders = ReminderStore.shared.loadAll()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    @MainActor
    func toggleReminder(for date: ImportantDate) async {
        let existing = reminders[date.id]
        let wasEnabled = existing?.reminderEnabled ?? false

        if !wasEnabled {
            let granted = await NotificationService.shared.requestPermission()
            if !granted {
                permissionDenied = true
                return
            }
        }

        let time = existing?.reminderTime ?? .dayBefore
        var pref = ReminderPreference(
            dateId: date.id,
            classId: date.classId,
            title: date.title,
            date: date.date,
            reminderEnabled: !wasEnabled,
            reminderTime: time
        )

        if pref.reminderEnabled {
            NotificationService.shared.scheduleReminder(for: date, time: time)
        } else {
            NotificationService.shared.cancelReminder(dateId: date.id)
        }

        reminders[date.id] = pref
        ReminderStore.shared.setPreference(pref)
    }

    @MainActor
    func updateReminderTime(for date: ImportantDate, time: ReminderTime) {
        guard var pref = reminders[date.id] else { return }
        pref.reminderTime = time

        if pref.reminderEnabled {
            NotificationService.shared.cancelReminder(dateId: date.id)
            NotificationService.shared.scheduleReminder(for: date, time: time)
        }

        reminders[date.id] = pref
        ReminderStore.shared.setPreference(pref)
    }
}
