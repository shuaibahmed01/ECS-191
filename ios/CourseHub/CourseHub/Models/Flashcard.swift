import Foundation

struct Flashcard: Codable, Identifiable {
    var id = UUID()
    let question: String
    let answer: String

    enum CodingKeys: String, CodingKey {
        case question
        case answer
    }
}

struct FlashcardData: Codable {
    let cards: [Flashcard]
    let generatedAt: String

    enum CodingKeys: String, CodingKey {
        case cards
        case generatedAt = "generated_at"
    }
}

struct FlashcardResponse: Codable {
    let flashcards: FlashcardData
}
