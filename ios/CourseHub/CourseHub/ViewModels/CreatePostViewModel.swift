import Foundation

@Observable
class CreatePostViewModel {
    var title: String = ""
    var body: String = ""
    var isSubmitting: Bool = false
    var errorMessage: String?
    var didCreate: Bool = false

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @MainActor
    func submit(courseId: String) async {
        guard isValid else { return }
        isSubmitting = true
        errorMessage = nil

        do {
            _ = try await APIClient.shared.createPost(
                courseId: courseId,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                body: body.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            didCreate = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isSubmitting = false
    }
}
