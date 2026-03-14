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
            .filter {
                let effectiveDate = effectiveParsedDate(for: $0) ?? .distantPast
                return effectiveDate >= now
            }
            .sorted {
                (effectiveParsedDate(for: $0) ?? .distantPast) < (effectiveParsedDate(for: $1) ?? .distantPast)
            }
    }

    var datesByMonth: [(String, [ImportantDate])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        var grouped: [String: [ImportantDate]] = [:]
        var order: [String] = []
        for date in upcomingDates {
            let key = effectiveParsedDate(for: date).map { formatter.string(from: $0) } ?? "Unknown"
            if grouped[key] == nil { order.append(key) }
            grouped[key, default: []].append(date)
        }
        return order.map { ($0, grouped[$0]!) }
    }

    func effectiveDateString(for date: ImportantDate) -> String {
        reminders[date.id]?.customDate ?? date.date
    }

    func effectiveParsedDate(for date: ImportantDate) -> Date? {
        let dateString = effectiveDateString(for: date)
        return ImportantDate.parseDate(dateString)
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
        let customDate = existing?.customDate
        let pref = ReminderPreference(
            dateId: date.id,
            classId: date.classId,
            title: date.title,
            date: date.date,
            reminderEnabled: !wasEnabled,
            reminderTime: time,
            customDate: customDate
        )

        if pref.reminderEnabled {
            NotificationService.shared.scheduleReminder(for: date, time: time, customDate: customDate)
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
            NotificationService.shared.scheduleReminder(for: date, time: time, customDate: pref.customDate)
        }

        reminders[date.id] = pref
        ReminderStore.shared.setPreference(pref)
    }

    @MainActor
    func updateEventDate(for date: ImportantDate, newDate: Date) {
        let dateString = ImportantDate.dateTimeFormatter.string(from: newDate)
        var pref = reminders[date.id] ?? ReminderPreference(
            dateId: date.id,
            classId: date.classId,
            title: date.title,
            date: date.date,
            reminderEnabled: false,
            reminderTime: .dayBefore,
            customDate: nil
        )
        pref.customDate = dateString

        if pref.reminderEnabled {
            NotificationService.shared.cancelReminder(dateId: date.id)
            NotificationService.shared.scheduleReminder(for: date, time: pref.reminderTime, customDate: dateString)
        }

        reminders[date.id] = pref
        ReminderStore.shared.setPreference(pref)
    }
}
