import SwiftUI

struct SyllabusUploadView: View {
    @State private var viewModel: SyllabusUploadViewModel
    @State private var showDocumentPicker = false
    @State private var showCamera = false
    @State private var editingField: String?
    @State private var editingTitle = ""
    @State private var editText = ""
    @Environment(\.dismiss) private var dismiss

    let classCode: String

    init(classId: String, classCode: String) {
        self._viewModel = State(initialValue: SyllabusUploadViewModel(classId: classId))
        self.classCode = classCode
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isProcessing {
                    processingView
                } else if let context = viewModel.syllabusContext {
                    syllabusDetailView(context)
                } else {
                    uploadPromptView
                }
            }
            .navigationTitle("Syllabus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                if viewModel.hasExistingSyllabus {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button {
                                showDocumentPicker = true
                            } label: {
                                Label("Upload New PDF", systemImage: "doc.fill")
                            }
                            Button {
                                showCamera = true
                            } label: {
                                Label("Take New Photo", systemImage: "camera.fill")
                            }
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                    }
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPicker { data in
                    showDocumentPicker = false
                    Task { await viewModel.uploadPDF(data: data) }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in
                    showCamera = false
                    Task { await viewModel.uploadImage(image) }
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: Binding(
                get: { editingField != nil },
                set: { if !$0 { editingField = nil } }
            )) {
                NavigationStack {
                    VStack {
                        TextEditor(text: $editText)
                            .padding()
                    }
                    .navigationTitle("Edit \(editingTitle)")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                editingField = nil
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            if viewModel.isSaving {
                                ProgressView()
                            } else {
                                Button("Save") {
                                    guard let field = editingField else { return }
                                    Task {
                                        await viewModel.updateField(field, value: editText)
                                        editingField = nil
                                    }
                                }
                            }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .task {
                await viewModel.loadExistingSyllabus()
            }
        }
    }

    private var processingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Analyzing syllabus...")
                .font(.headline)
            Text("This may take a moment")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var uploadPromptView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("Upload Your Syllabus")
                .font(.title2.bold())

            Text("Upload a PDF or take a photo of your syllabus. We'll extract key information like grading policies, important dates, and more.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 12) {
                Button {
                    showDocumentPicker = true
                } label: {
                    Label("Choose PDF", systemImage: "doc.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    showCamera = true
                } label: {
                    Label("Take Photo", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    private func syllabusDetailView(_ context: SyllabusContext) -> some View {
        List {
            infoSection(title: "Instructor", field: "instructor", icon: "person.fill", color: .blue, content: context.instructor)
            infoSection(title: "Office Hours", field: "office_hours", icon: "clock.fill", color: .green, content: context.officeHours)
            infoSection(title: "Grading Policy", field: "grading_policy", icon: "chart.bar.fill", color: .orange, content: context.gradingPolicy)
            infoSection(title: "Important Dates", field: "important_dates", icon: "calendar", color: .red, content: context.importantDates)
            infoSection(title: "Course Policies", field: "course_policies", icon: "list.clipboard.fill", color: .purple, content: context.coursePolicies)

            Section {
                Button {
                    showDocumentPicker = true
                } label: {
                    Label("Upload New Syllabus (PDF)", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                Button {
                    showCamera = true
                } label: {
                    Label("Retake Syllabus Photo", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } header: {
                Text("Wrong syllabus?")
            } footer: {
                Text("Re-upload if the wrong document was processed.")
            }
        }
    }

    private func infoSection(title: String, field: String, icon: String, color: Color, content: String) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .foregroundStyle(color)
                    Text(title)
                        .font(.headline)
                    Spacer()
                    Image(systemName: "pencil")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                Text(content.markdownFormatted)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .onTapGesture {
                editingTitle = title
                editText = content
                editingField = field
            }
        }
    }
}
