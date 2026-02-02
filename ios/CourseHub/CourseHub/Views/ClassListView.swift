import SwiftUI

struct ClassListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ClassListViewModel()
    var enrolledClassIds: Set<Int> = []
    var onClassAdded: (() -> Void)?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading classes...")
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
                } else {
                    List(viewModel.filteredClasses.filter { !enrolledClassIds.contains($0.id) }) { course in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(course.classCode)
                                    .font(.headline)
                                Text(course.className)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("Add") {
                                Task {
                                    await viewModel.addClass(classId: course.id)
                                    onClassAdded?()
                                    dismiss()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }
            .navigationTitle("Add Class")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Search classes")
            .task {
                await viewModel.loadClasses()
            }
            .refreshable {
                await viewModel.loadClasses()
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil && !viewModel.isLoading)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}

#Preview {
    ClassListView()
}
