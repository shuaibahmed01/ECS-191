import SwiftUI

@main
struct CourseHubApp: App {
    init() {
        // Seed database on app launch
        Task {
            await APIClient.shared.seedDatabase()
        }
    }

    var body: some Scene {
        WindowGroup {
            MyScheduleView()
        }
    }
}
