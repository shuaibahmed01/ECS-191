import Foundation

struct ForumPost: Codable, Identifiable {
    let id: String
    let courseId: String
    let authorId: String
    let authorName: String
    let title: String
    let body: String
    var upvoteCount: Int
    var commentCount: Int
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case courseId = "course_id"
        case authorId = "author_id"
        case authorName = "author_name"
        case title
        case body
        case upvoteCount = "upvote_count"
        case commentCount = "comment_count"
        case createdAt = "created_at"
    }
}

struct ForumComment: Codable, Identifiable {
    let id: String
    let postId: String
    let authorId: String
    let authorName: String
    let body: String
    let parentCommentId: String?
    let path: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case authorId = "author_id"
        case authorName = "author_name"
        case body
        case parentCommentId = "parent_comment_id"
        case path
        case createdAt = "created_at"
    }

    var depth: Int {
        path.components(separatedBy: "/").count - 1
    }
}

struct PostListResponse: Codable {
    let posts: [ForumPost]
}

struct PostDetailResponse: Codable {
    let post: ForumPost
    let comments: [ForumComment]
    let hasUpvoted: Bool

    enum CodingKeys: String, CodingKey {
        case post
        case comments
        case hasUpvoted = "has_upvoted"
    }
}

struct UpvoteResponse: Codable {
    let upvoted: Bool
    let upvoteCount: Int

    enum CodingKeys: String, CodingKey {
        case upvoted
        case upvoteCount = "upvote_count"
    }
}
