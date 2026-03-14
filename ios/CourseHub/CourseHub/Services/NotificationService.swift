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

    func scheduleReminder(for date: ImportantDate, time: ReminderTime) {
        guard let eventDate = date.parsedDate else { return }

        let content = UNMutableNotificationContent()
        content.title = date.title
        content.body = "\(date.classCode) — \(date.description)"
        content.sound = .default

        let calendar = Calendar.current
        guard let triggerDate = calendar.date(byAdding: .hour, value: time.hourOffset, to: eventDate) else { return }

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

    func cancelReminder(dateId: String) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [dateId])
    }
}
