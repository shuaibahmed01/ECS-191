import Foundation
import UIKit

@Observable
class SlidesViewModel {
    var slides: [SlideEntry] = []
    var isLoading = false
    var isUploading = false
    var errorMessage: String?
    var flashcardsBySlideId: [String: [Flashcard]] = [:]
    var isGeneratingFlashcards: Set<String> = []

    private let classId: String

    init(classId: String) {
        self.classId = classId
    }

    @MainActor
    func loadSlides() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await APIClient.shared.getSlides(classId: classId)
            slides = response.slides
            for slide in slides {
                await loadFlashcards(for: slide.id)
            }
        } catch is CancellationError {
        } catch {
            if !Task.isCancelled {
                errorMessage = (error as? APIError)?.localizedDescription ?? "Something went wrong. Please try again later."
            }
        }

        isLoading = false
    }

    @MainActor
    func generateFlashcards(for slideId: String) async {
        isGeneratingFlashcards.insert(slideId)
        do {
            let response = try await APIClient.shared.generateFlashcards(classId: classId, slideId: slideId)
            flashcardsBySlideId[slideId] = response.flashcards.cards
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? "Something went wrong. Please try again later."
        }
        isGeneratingFlashcards.remove(slideId)
    }

    @MainActor
    func loadFlashcards(for slideId: String) async {
        do {
            let response = try await APIClient.shared.getFlashcards(classId: classId, slideId: slideId)
            flashcardsBySlideId[slideId] = response.flashcards.cards
        } catch {
            // Silently ignore 404 (no flashcards yet)
        }
    }

    @MainActor
    func uploadPDF(data: Data, title: String) async {
        let base64 = data.base64EncodedString()
        await upload(fileData: base64, fileType: "application/pdf", title: title)
    }

    @MainActor
    func uploadImage(_ image: UIImage, title: String) async {
        guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
            errorMessage = "Failed to compress image"
            return
        }
        let base64 = jpegData.base64EncodedString()
        await upload(fileData: base64, fileType: "image/jpeg", title: title)
    }

    @MainActor
    func deleteSlide(id: String) async {
        do {
            try await APIClient.shared.deleteSlide(classId: classId, slideId: id)
            slides.removeAll { $0.id == id }
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? "Something went wrong. Please try again later."
        }
    }

    @MainActor
    private func upload(fileData: String, fileType: String, title: String) async {
        isUploading = true
        errorMessage = nil

        do {
            let response = try await APIClient.shared.uploadSlides(
                classId: classId,
                fileDataBase64: fileData,
                fileType: fileType,
                title: title
            )
            slides.append(response.slide)
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? "Something went wrong. Please try again later."
        }

        isUploading = false
    }
}
