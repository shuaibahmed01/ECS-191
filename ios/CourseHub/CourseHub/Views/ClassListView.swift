import SwiftUI

struct ClassListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ClassListViewModel()
    var enrolledClassIds: Set<String> = []
    var onClassAdded: (() -> Void)?
    @State private var showingCustomClass = false

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
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCustomClass = true
                    } label: {
                        Label("Add Custom", systemImage: "plus.square.on.square")
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
            .sheet(isPresented: $showingCustomClass) {
                CustomClassFormView { createdClass in
                    Task {
                        // Enroll in the newly created class, then refresh and dismiss
                        await viewModel.addClass(classId: createdClass.id)
                        onClassAdded?()
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ClassListView()
}

// MARK: - Custom Class Form
struct CustomClassFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var classCode: String = ""
    @State private var className: String = ""
    @State private var lectureTimesText: String = ""
    @State private var discussionTimesText: String = ""
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?

    var onCreated: (CourseClass) -> Void

    private var isValid: Bool {
        !classCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !className.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Class Code (e.g., MGT 120)", text: $classCode)
                        .textInputAutocapitalization(.characters)
                    TextField("Class Name (e.g., Marketing)", text: $className)
                }
                Section("Optional Times") {
                    TextField("Lecture times (comma-separated)", text: $lectureTimesText)
                    TextField("Discussion times (comma-separated)", text: $discussionTimesText)
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle("Custom Class")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("Create & Add")
                        }
                    }
                    .disabled(!isValid || isSubmitting)
                }
            }
        }
    }

    @MainActor
    private func submit() async {
        isSubmitting = true
        errorMessage = nil
        do {
            let lectureTimes = lectureTimesText
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            let discussionTimes = discussionTimesText
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            let created: CourseClass = try await APIClient.shared.createCustomClass(
                classCode: classCode.trimmingCharacters(in: .whitespacesAndNewlines),
                className: className.trimmingCharacters(in: .whitespacesAndNewlines),
                lectureTimes: lectureTimes.isEmpty ? nil : lectureTimes,
                discussionTimes: discussionTimes.isEmpty ? nil : discussionTimes
            )
            onCreated(created)
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }
}
