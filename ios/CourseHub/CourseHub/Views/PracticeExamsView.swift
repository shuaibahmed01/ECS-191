import SwiftUI

struct PracticeExamsView: View {
    let classId: String
    let classCode: String

    @State private var viewModel: PracticeExamViewModel
    @State private var showCreateSheet = false

    init(classId: String, classCode: String) {
        self.classId = classId
        self.classCode = classCode
        self._viewModel = State(initialValue: PracticeExamViewModel(classId: classId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.exams.isEmpty {
                ProgressView("Loading exams...")
            } else if viewModel.exams.isEmpty {
                ContentUnavailableView(
                    "No Practice Exams Yet",
                    systemImage: "doc.questionmark",
                    description: Text("Tap + to generate a practice exam from your lecture slides.")
                )
            } else {
                List(viewModel.exams) { exam in
                    NavigationLink {
                        TakePracticeExamView(classId: classId, examId: exam.id, viewModel: viewModel)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "doc.questionmark.fill")
                                .font(.title2)
                                .foregroundStyle(.indigo)
                                .frame(width: 36, height: 36)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(exam.title)
                                    .font(.headline)
                                HStack(spacing: 12) {
                                    Text("\(exam.questionCount) questions")
                                    Text("·")
                                    Text(exam.questionType.replacingOccurrences(of: "_", with: " ").capitalized)
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Practice Exams")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreatePracticeExamView(classId: classId, viewModel: viewModel) {
                showCreateSheet = false
            }
        }
        .task {
            await viewModel.loadExams()
        }
        .refreshable {
            await viewModel.loadExams()
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}
