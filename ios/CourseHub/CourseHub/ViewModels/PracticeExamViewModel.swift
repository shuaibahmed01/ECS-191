import Foundation

@Observable
class PracticeExamViewModel {
    var exams: [PracticeExamSummary] = []
    var currentExam: PracticeExam?
    var isLoading = false
    var isGenerating = false
    var isGrading = false
    var latestResults: ExamResults?
    var attempts: [ExamAttempt] = []
    var errorMessage: String?

    private let classId: String

    init(classId: String) {
        self.classId = classId
    }

    @MainActor
    func loadExams() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await APIClient.shared.getPracticeExams(classId: classId)
            exams = response.exams
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? "Something went wrong. Please try again later."
        }

        isLoading = false
    }

    @MainActor
    func createExam(
        title: String,
        slideIds: [String],
        description: String,
        questionCount: Int,
        questionType: ExamQuestionType
    ) async {
        isGenerating = true
        errorMessage = nil

        do {
            let response = try await APIClient.shared.createPracticeExam(
                classId: classId,
                title: title,
                slideIds: slideIds,
                description: description,
                questionCount: questionCount,
                questionType: questionType.rawValue
            )
            currentExam = response.exam
            // Refresh list
            await loadExams()
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? "Something went wrong. Please try again later."
        }

        isGenerating = false
    }

    @MainActor
    func loadExam(examId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await APIClient.shared.getPracticeExam(classId: classId, examId: examId)
            currentExam = response.exam
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? "Something went wrong. Please try again later."
        }

        // Don't set isLoading = false here — let loadExamWithAttempts handle it
    }

    @MainActor
    func loadExamWithAttempts(examId: String) async {
        isLoading = true
        errorMessage = nil
        latestResults = nil

        await loadExam(examId: examId)
        await loadAttempts(examId: examId)

        isLoading = false
    }

    @MainActor
    func submitExam(examId: String, answers: [[String: Any]]) async {
        isGrading = true
        errorMessage = nil

        do {
            let response = try await APIClient.shared.submitPracticeExam(
                classId: classId,
                examId: examId,
                answers: answers
            )
            latestResults = response.results
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? "Something went wrong. Please try again later."
        }

        isGrading = false
    }

    @MainActor
    func loadAttempts(examId: String) async {
        do {
            let response = try await APIClient.shared.getExamAttempts(classId: classId, examId: examId)
            attempts = response.attempts
        } catch {
            // Silently fail — attempts are non-critical
            attempts = []
        }
    }
}
