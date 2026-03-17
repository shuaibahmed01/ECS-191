import SwiftUI

struct TakePracticeExamView: View {
    let classId: String
    let examId: String
    @Bindable var viewModel: PracticeExamViewModel

    @State private var answers: [Int: String] = [:]
    @State private var showResults = false
    @State private var hasExistingAttempt = false

    private var mcQuestions: [(Int, ExamQuestion)] {
        guard let exam = viewModel.currentExam else { return [] }
        return Array(exam.questions.enumerated()).filter { $0.element.isMultipleChoice }
    }

    private var saQuestions: [(Int, ExamQuestion)] {
        guard let exam = viewModel.currentExam else { return [] }
        return Array(exam.questions.enumerated()).filter { !$0.element.isMultipleChoice }
    }

    private var isMixed: Bool {
        !mcQuestions.isEmpty && !saQuestions.isEmpty
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading exam...")
            } else if hasExistingAttempt, let results = viewModel.latestResults, let exam = viewModel.currentExam {
                ExamResultsView(
                    results: results,
                    questions: exam.questions,
                    onRetry: {
                        hasExistingAttempt = false
                        viewModel.latestResults = nil
                        answers = [:]
                    }
                )
            } else if let exam = viewModel.currentExam {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exam.title)
                                .font(.title2.bold())
                            if !exam.description.isEmpty {
                                Text(exam.description)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Text("\(exam.questions.count) questions")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)

                        if isMixed {
                            // MC Section
                            sectionHeader("Multiple Choice", icon: "list.bullet.circle.fill")
                            ForEach(mcQuestions, id: \.0) { index, question in
                                questionCard(index: index, question: question)
                            }

                            // SA Section
                            sectionHeader("Short Answer", icon: "text.bubble.fill")
                            ForEach(saQuestions, id: \.0) { index, question in
                                questionCard(index: index, question: question)
                            }
                        } else {
                            ForEach(Array(exam.questions.enumerated()), id: \.offset) { index, question in
                                questionCard(index: index, question: question)
                            }
                        }

                        // Submit
                        Button {
                            Task {
                                let answerList = (0..<exam.questions.count).map { i in
                                    ["question_index": i, "answer": answers[i] ?? ""] as [String: Any]
                                }
                                await viewModel.submitExam(examId: examId, answers: answerList)
                                if viewModel.latestResults != nil {
                                    hasExistingAttempt = true
                                }
                            }
                        } label: {
                            Text("Submit Exam")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(answers.count < exam.questions.count || viewModel.isGrading)
                        .padding()
                    }
                    .padding(.vertical)
                }
                .background(Color(.systemGroupedBackground))
                .overlay {
                    if viewModel.isGrading {
                        gradingOverlay
                    }
                }
            } else {
                ContentUnavailableView("Exam not found", systemImage: "exclamationmark.triangle")
            }
        }
        .navigationTitle("Take Exam")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadExamWithAttempts(examId: examId)
            if let lastAttempt = viewModel.attempts.last {
                viewModel.latestResults = lastAttempt.results
                hasExistingAttempt = true
            }
        }
    }

    // MARK: - Components

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private func questionCard(index: Int, question: ExamQuestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Q\(index + 1). \(question.question)")
                .font(.body.bold())

            if question.isMultipleChoice, let options = question.options {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(options, id: \.self) { option in
                        Button {
                            answers[index] = option
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: answers[index] == option ? "circle.inset.filled" : "circle")
                                    .foregroundStyle(answers[index] == option ? .blue : .secondary)
                                    .font(.body)
                                    .padding(.top, 2)
                                Text(option)
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer()
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
            } else {
                TextEditor(text: Binding(
                    get: { answers[index] ?? "" },
                    set: { answers[index] = $0 }
                ))
                .frame(minHeight: 80)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3))
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        .padding(.horizontal)
    }

    private var gradingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.3)
                Text("Grading your exam...")
                    .font(.headline)
                Text("AI is reviewing your answers")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(32)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }
}
