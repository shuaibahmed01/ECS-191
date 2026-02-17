import SwiftUI

struct CreatePostView: View {
    let courseId: String
    var onPostCreated: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = CreatePostViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Post title", text: $viewModel.title)
                }

                Section("Body") {
                    TextEditor(text: $viewModel.body)
                        .frame(minHeight: 120)
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        Task {
                            await viewModel.submit(courseId: courseId)
                        }
                    }
                    .disabled(!viewModel.isValid || viewModel.isSubmitting)
                }
            }
            .onChange(of: viewModel.didCreate) {
                if viewModel.didCreate {
                    onPostCreated?()
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    CreatePostView(courseId: "ecs_032a")
}
