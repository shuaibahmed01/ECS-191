import SwiftUI

struct CreatePracticeExamView: View {
    let classId: String
    @Bindable var viewModel: PracticeExamViewModel
    var onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var questionCount = 10
    @State private var questionType: ExamQuestionType = .mixed
    @State private var slides: [SlideEntry] = []
    @State private var selectedSlideIds: Set<String> = []
    @State private var isLoadingSlides = true

    private var canGenerate: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && !selectedSlideIds.isEmpty && !viewModel.isGenerating
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("e.g. Midterm Review", text: $title)
                }

                Section("Select Slides") {
                    if isLoadingSlides {
                        ProgressView("Loading slides...")
                    } else if slides.isEmpty {
                        Text("No slides uploaded yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(slides) { slide in
                            Button {
                                if selectedSlideIds.contains(slide.id) {
                                    selectedSlideIds.remove(slide.id)
                                } else {
                                    selectedSlideIds.insert(slide.id)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: selectedSlideIds.contains(slide.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedSlideIds.contains(slide.id) ? .blue : .secondary)
                                    Text(slide.title)
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                    }
                }

                Section("Questions") {
                    Stepper("Count: \(questionCount)", value: $questionCount, in: 1...15)
                }

                Section("Question Type") {
                    Picker("Type", selection: $questionType) {
                        ForEach(ExamQuestionType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Focus Area (Optional)") {
                    TextField("e.g. Chapter 5 concepts", text: $description)
                }
            }
            .navigationTitle("New Practice Exam")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(viewModel.isGenerating)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Generate") {
                        Task {
                            await viewModel.createExam(
                                title: title.trimmingCharacters(in: .whitespaces),
                                slideIds: Array(selectedSlideIds),
                                description: description.trimmingCharacters(in: .whitespaces),
                                questionCount: questionCount,
                                questionType: questionType
                            )
                            if viewModel.errorMessage == nil {
                                onDismiss()
                            }
                        }
                    }
                    .disabled(!canGenerate)
                }
            }
            .task {
                do {
                    let response = try await APIClient.shared.getSlides(classId: classId)
                    slides = response.slides
                } catch {
                    // slides remain empty
                }
                isLoadingSlides = false
            }
            .allowsHitTesting(!viewModel.isGenerating)
            .overlay {
                if viewModel.isGenerating {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.3)
                            Text("Generating Practice Exam...")
                                .font(.headline)
                            Text("AI is creating questions from your slides")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(32)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                }
            }
        }
        .interactiveDismissDisabled(viewModel.isGenerating)
    }
}
