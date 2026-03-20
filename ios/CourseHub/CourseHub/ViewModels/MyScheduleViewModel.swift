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
            errorMessage = (error as? APIError)?.localizedDescription ?? "Something went wrong. Please try again later."
        }

        isLoading = false
    }

    @MainActor
    func removeClass(enrollmentId: String) async {
        errorMessage = nil

        do {
            try await APIClient.shared.unenroll(enrollmentId: enrollmentId)
            enrolledClasses.removeAll { $0.enrollmentId == enrollmentId }
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? "Something went wrong. Please try again later."
        }
    }
}
