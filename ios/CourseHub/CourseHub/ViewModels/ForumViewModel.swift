import Foundation

@Observable
class ForumViewModel {
    var posts: [ForumPost] = []
    var isLoading: Bool = false
    var errorMessage: String?

    @MainActor
    func loadPosts(courseId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            posts = try await APIClient.shared.fetchPosts(courseId: courseId)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
