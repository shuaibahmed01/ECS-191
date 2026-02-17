import SwiftUI

struct ForumCourseListView: View {
    @State private var viewModel = ClassListViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading courses...")
                } else if let error = viewModel.errorMessage {
                    VStack {
                        Text("Error")
                            .font(.headline)
                        Text(error)
                            .foregroundColor(.red)
                        Button("Retry") {
                            Task {
                                await viewModel.loadClasses()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                } else if viewModel.filteredClasses.isEmpty {
                    ContentUnavailableView(
                        "No Courses",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("No courses available")
                    )
                } else {
                    List(viewModel.filteredClasses) { course in
                        NavigationLink {
                            ForumPostListView(courseId: course.id, courseName: course.classCode)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(course.classCode)
                                    .font(.headline)
                                Text(course.className)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Forum")
            .searchable(text: $viewModel.searchText, prompt: "Search courses")
            .task {
                await viewModel.loadClasses()
            }
            .refreshable {
                await viewModel.loadClasses()
            }
        }
    }
}

#Preview {
    ForumCourseListView()
}
