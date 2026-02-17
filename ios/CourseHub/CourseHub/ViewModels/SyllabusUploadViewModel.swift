import Foundation
import UIKit

@Observable
class SyllabusUploadViewModel {
    var isProcessing = false
    var isSaving = false
    var errorMessage: String?
    var syllabusContext: SyllabusContext?
    var hasExistingSyllabus = false

    private let classId: String

    init(classId: String) {
        self.classId = classId
    }

    @MainActor
    func loadExistingSyllabus() async {
        do {
            let response = try await APIClient.shared.getSyllabusContext(classId: classId)
            syllabusContext = response.syllabus
            hasExistingSyllabus = true
        } catch let error as APIError {
            if case .httpError(404) = error {
                // No syllabus yet — that's fine
                hasExistingSyllabus = false
            } else {
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func uploadPDF(data: Data) async {
        let base64 = data.base64EncodedString()
        await upload(fileData: base64, fileType: "application/pdf")
    }

    @MainActor
    func uploadImage(_ image: UIImage) async {
        guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
            errorMessage = "Failed to compress image"
            return
        }
        let base64 = jpegData.base64EncodedString()
        await upload(fileData: base64, fileType: "image/jpeg")
    }

    @MainActor
    func updateField(_ field: String, value: String) async {
        isSaving = true
        errorMessage = nil

        do {
            let response = try await APIClient.shared.updateSyllabus(
                classId: classId,
                fields: [field: value]
            )
            syllabusContext = response.syllabus
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }

    @MainActor
    private func upload(fileData: String, fileType: String) async {
        isProcessing = true
        errorMessage = nil

        do {
            let response = try await APIClient.shared.uploadSyllabus(
                classId: classId,
                fileDataBase64: fileData,
                fileType: fileType
            )
            syllabusContext = response.syllabus
            hasExistingSyllabus = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }
}
