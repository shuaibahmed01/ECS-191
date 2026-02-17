import SwiftUI

struct PostDetailView: View {
    let courseId: String
    let postId: String

    @State private var viewModel = PostDetailViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading post...")
            } else if let post = viewModel.post {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            // Post header
                            VStack(alignment: .leading, spacing: 8) {
                                Text(post.title)
                                    .font(.title2)
                                    .fontWeight(.bold)

                                HStack {
                                    Text(post.authorName)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }

                                Text(post.body)
                                    .font(.body)

                                // Upvote button
                                Button {
                                    Task {
                                        await viewModel.toggleUpvote(courseId: courseId, postId: postId)
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: viewModel.hasUpvoted ? "arrow.up.circle.fill" : "arrow.up.circle")
                                        Text("\(post.upvoteCount)")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(viewModel.hasUpvoted ? .blue : .secondary)
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(.horizontal)

                            Divider()

                            // Comments section
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Comments (\(viewModel.comments.count))")
                                    .font(.headline)
                                    .padding(.horizontal)

                                if viewModel.comments.isEmpty {
                                    Text("No comments yet")
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal)
                                } else {
                                    ForEach(viewModel.comments) { comment in
                                        CommentRowView(comment: comment) {
                                            viewModel.replyingTo = comment
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.top)
                    }

                    Divider()

                    // Comment input
                    VStack(spacing: 4) {
                        if let replyTarget = viewModel.replyingTo {
                            HStack {
                                Text("Replying to \(replyTarget.authorName)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button {
                                    viewModel.replyingTo = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal)
                        }

                        HStack {
                            TextField("Add a comment...", text: $viewModel.commentText)
                                .textFieldStyle(.roundedBorder)

                            Button {
                                Task {
                                    await viewModel.sendComment(courseId: courseId, postId: postId)
                                }
                            } label: {
                                Image(systemName: "paperplane.fill")
                            }
                            .disabled(viewModel.commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                }
            } else if let error = viewModel.errorMessage {
                VStack {
                    Text("Error")
                        .font(.headline)
                    Text(error)
                        .foregroundColor(.red)
                    Button("Retry") {
                        Task {
                            await viewModel.loadDetail(courseId: courseId, postId: postId)
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadDetail(courseId: courseId, postId: postId)
        }
    }
}

struct CommentRowView: View {
    let comment: ForumComment
    let onReply: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Indentation based on depth
            if comment.depth > 0 {
                Rectangle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: 2)
                    .padding(.leading, CGFloat(comment.depth) * 16)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(comment.authorName)
                    .font(.caption)
                    .fontWeight(.semibold)

                Text(comment.body)
                    .font(.subheadline)

                Button("Reply") {
                    onReply()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Spacer()
        }
    }
}

#Preview {
    NavigationStack {
        PostDetailView(courseId: "ecs_032a", postId: "post_1")
    }
}
