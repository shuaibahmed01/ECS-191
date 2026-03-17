import Foundation

enum ExamQuestionType: String, Codable, CaseIterable {
    case multipleChoice = "multiple_choice"
    case shortAnswer = "short_answer"
    case mixed = "mixed"

    var displayName: String {
        switch self {
        case .multipleChoice: return "Multiple Choice"
        case .shortAnswer: return "Short Answer"
        case .mixed: return "Mixed"
        }
    }
}

struct ExamQuestion: Codable, Identifiable {
    var id = UUID()
    let type: String
    let question: String
    let options: [String]?
    let correctAnswer: String?
    let expectedAnswer: String?

    enum CodingKeys: String, CodingKey {
        case type, question, options
        case correctAnswer = "correct_answer"
        case expectedAnswer = "expected_answer"
    }

    var isMultipleChoice: Bool { type == "multiple_choice" }
}

struct PracticeExamSummary: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let questionCount: Int
    let questionType: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, title, description
        case questionCount = "question_count"
        case questionType = "question_type"
        case createdAt = "created_at"
    }
}

struct PracticeExam: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let slideIds: [String]
    let questionCount: Int
    let questionType: String
    let questions: [ExamQuestion]
    let createdBy: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, title, description, questions
        case slideIds = "slide_ids"
        case questionCount = "question_count"
        case questionType = "question_type"
        case createdBy = "created_by"
        case createdAt = "created_at"
    }
}

struct QuestionResult: Codable {
    let questionIndex: Int
    let correct: Bool
    let partial: Bool?
    let explanation: String

    enum CodingKeys: String, CodingKey {
        case questionIndex = "question_index"
        case correct, partial, explanation
    }
}

struct ExamResults: Codable {
    let score: Int
    let total: Int
    let perQuestion: [QuestionResult]
    let feedback: String

    enum CodingKeys: String, CodingKey {
        case score, total, feedback
        case perQuestion = "per_question"
    }
}

struct ExamAttempt: Codable, Identifiable {
    let id: String
    let results: ExamResults
    let submittedAt: String

    enum CodingKeys: String, CodingKey {
        case id, results
        case submittedAt = "submitted_at"
    }
}

struct PracticeExamListResponse: Codable {
    let exams: [PracticeExamSummary]
}

struct PracticeExamResponse: Codable {
    let exam: PracticeExam
}

struct ExamGradeResponse: Codable {
    let results: ExamResults
}

struct ExamAttemptsResponse: Codable {
    let attempts: [ExamAttempt]
}
