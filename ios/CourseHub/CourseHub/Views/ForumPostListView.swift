import SwiftUI

struct ForumPostListView: View {
    let courseId: String
    let courseName: String

    @State private var viewModel = ForumViewModel()
    @State private var showingCreatePost = false

    var body: some View {
        ZStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading posts...")
                } else if viewModel.posts.isEmpty {
                    ContentUnavailableView(
                        "No Posts Yet",
                        systemImage: "text.bubble",
                        description: Text("Be the first to post!")
                    )
                } else {
                    List(viewModel.posts) { post in
                        NavigationLink {
                            PostDetailView(courseId: courseId, postId: post.id)
                        } label: {
                            PostRowView(post: post)
                        }
                    }
                }
            }

            // Floating New Post Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        showingCreatePost = true
                    } label: {
                        HStack {
                            Image(systemName: "plus")
                            Text("New Post")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .clipShape(Capsule())
                        .shadow(radius: 4)
                    }
                    Spacer()
                }
                .padding(.bottom, 16)
            }
        }
        .navigationTitle(courseName)
        .sheet(isPresented: $showingCreatePost) {
            CreatePostView(courseId: courseId) {
                Task {
                    await viewModel.loadPosts(courseId: courseId)
                }
            }
        }
        .task {
            await viewModel.loadPosts(courseId: courseId)
        }
        .refreshable {
            await viewModel.loadPosts(courseId: courseId)
        }
    }
}

struct PostRowView: View {
    let post: ForumPost

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(post.title)
                .font(.headline)
                .lineLimit(2)

            Text(post.body)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)

            HStack(spacing: 16) {
                Label("\(post.upvoteCount)", systemImage: "arrow.up")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Label("\(post.commentCount)", systemImage: "bubble.right")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(post.authorName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        ForumPostListView(courseId: "ecs_032a", courseName: "ECS 032A")
    }
}
