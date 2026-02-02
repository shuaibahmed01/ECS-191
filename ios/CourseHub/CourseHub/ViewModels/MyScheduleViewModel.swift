import Foundation

@Observable
class MyScheduleViewModel {
    var enrolledClasses: [UserScheduleEntry] = []
    var isLoading: Bool = false
    var errorMessage: String?

    @MainActor
    func loadSchedule() async {
        isLoading = true
        errorMessage = nil

        do {
            enrolledClasses = try await APIClient.shared.fetchMyClasses()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    @MainActor
    func removeClass(enrollmentId: Int) async {
        errorMessage = nil

        do {
            try await APIClient.shared.unenroll(enrollmentId: enrollmentId)
            enrolledClasses.removeAll { $0.enrollmentId == enrollmentId }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
