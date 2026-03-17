import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    func scheduleReminder(for date: ImportantDate, time: ReminderTime, customDate: String? = nil) {
        let dateString = customDate ?? date.date
        guard let eventDate = ImportantDate.parseDate(dateString) else { return }

        let calendar = Calendar.current
        guard let triggerDate = calendar.date(byAdding: .hour, value: time.hourOffset, to: eventDate) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Reminder: \(date.classCode)"
        content.body = "You have a \(date.title) \(relativeTimeString(from: triggerDate, to: eventDate)) at \(formattedTime(eventDate))"
        content.sound = .default

        // Don't schedule notifications in the past
        if triggerDate <= Date() { return }

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: date.id,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func relativeTimeString(from now: Date, to eventDate: Date) -> String {
        let calendar = Calendar.current
        let startOfNow = calendar.startOfDay(for: now)
        let startOfEvent = calendar.startOfDay(for: eventDate)
        let daysBetween = calendar.dateComponents([.day], from: startOfNow, to: startOfEvent).day ?? 0

        switch daysBetween {
        case 0: return "today"
        case 1: return "tomorrow"
        case 2: return "the day after tomorrow"
        default: return "in \(daysBetween) days"
        }
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }

    func cancelReminder(dateId: String) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [dateId])
    }
}
