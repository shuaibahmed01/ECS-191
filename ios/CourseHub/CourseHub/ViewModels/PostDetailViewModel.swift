import Foundation

@Observable
class PostDetailViewModel {
    var post: ForumPost?
    var comments: [ForumComment] = []
    var hasUpvoted: Bool = false
    var isLoading: Bool = false
    var errorMessage: String?
    var commentText: String = ""
    var replyingTo: ForumComment?

    @MainActor
    func loadDetail(courseId: String, postId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let detail = try await APIClient.shared.fetchPostDetail(courseId: courseId, postId: postId)
            post = detail.post
            comments = detail.comments
            hasUpvoted = detail.hasUpvoted
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    @MainActor
    func toggleUpvote(courseId: String, postId: String) async {
        // Optimistic update
        hasUpvoted.toggle()
        post?.upvoteCount += hasUpvoted ? 1 : -1

        do {
            let result = try await APIClient.shared.toggleUpvote(courseId: courseId, postId: postId)
            hasUpvoted = result.upvoted
            post?.upvoteCount = result.upvoteCount
        } catch {
            // Revert optimistic update
            hasUpvoted.toggle()
            post?.upvoteCount += hasUpvoted ? 1 : -1
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func sendComment(courseId: String, postId: String) async {
        let body = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }

        let parentId = replyingTo?.id
        commentText = ""
        replyingTo = nil

        do {
            let comment = try await APIClient.shared.createComment(
                courseId: courseId,
                postId: postId,
                body: body,
                parentCommentId: parentId
            )
            comments.append(comment)
            comments.sort { $0.path < $1.path }
            post?.commentCount += 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
