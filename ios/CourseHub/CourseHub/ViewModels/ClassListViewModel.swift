import Foundation

@Observable
class ClassListViewModel {
    var allClasses: [CourseClass] = []
    var searchText: String = ""
    var isLoading: Bool = false
    var errorMessage: String?

    var filteredClasses: [CourseClass] {
        if searchText.isEmpty {
            return allClasses
        }
        return allClasses.filter { course in
            course.classCode.localizedCaseInsensitiveContains(searchText) ||
            course.className.localizedCaseInsensitiveContains(searchText)
        }
    }

    @MainActor
    func loadClasses() async {
        isLoading = true
        errorMessage = nil

        do {
            allClasses = try await APIClient.shared.fetchClasses()
        } catch is CancellationError {
        } catch {
            if !Task.isCancelled {
                errorMessage = (error as? APIError)?.localizedDescription ?? "Something went wrong. Please try again later."
            }
        }

        isLoading = false
    }

    @MainActor
    func addClass(classId: String) async {
        errorMessage = nil

        do {
            _ = try await APIClient.shared.enrollInClass(classId: classId)
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? "Something went wrong. Please try again later."
        }
    }
}
