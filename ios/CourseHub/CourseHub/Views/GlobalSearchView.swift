import SwiftUI

struct GlobalSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""
    @State private var isSearching: Bool = false
    @State private var errorMessage: String?
    @State private var results: [APIClient.GlobalSearchResult] = []
    // Navigation pushes
    @State private var pushChat = false
    @State private var chatClassId: String = ""
    @State private var chatClassCode: String = ""
    @State private var pushSyllabus = false
    @State private var syllabusClassId: String = ""
    @State private var syllabusClassCode: String = ""
    @State private var syllabusField: String = ""
    
    var body: some View {
        VStack {
            if results.isEmpty && !isSearching {
                ContentUnavailableView("Search", systemImage: "magnifyingglass", description: Text("Search syllabus and recent chat across your classes"))
            } else {
                List(results) { r in
                    Button {
                        handleTap(result: r)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: r.type == "chat" ? "bubble.left.and.bubble.right" : "doc.text")
                                .foregroundStyle(r.type == "chat" ? .blue : .orange)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(title(for: r))
                                        .font(.headline)
                                    Spacer()
                                    if let code = r.classCode {
                                        Text(code)
                                            .font(.caption2)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(10)
                                    }
                                }
                                Text(r.snippet)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        // Back button remains via parent NavigationStack
        .searchable(text: $query, prompt: "Search syllabus and chat")
        .onSubmit(of: .search) {
            Task { await runSearch() }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .navigationDestination(isPresented: $pushChat) {
            ChatView(classId: chatClassId, classCode: chatClassCode.isEmpty ? chatClassId : chatClassCode)
        }
        .navigationDestination(isPresented: $pushSyllabus) {
            SyllabusUploadView(classId: syllabusClassId, classCode: syllabusClassCode.isEmpty ? syllabusClassId : syllabusClassCode, highlightField: syllabusField)
        }
    }
    
    private func title(for r: APIClient.GlobalSearchResult) -> String {
        switch r.type {
        case "chat":
            return "Chat • \(r.senderName ?? "")"
        case "syllabus":
            if let f = r.field {
                switch f {
                case "instructor": return "Syllabus • Instructor"
                case "office_hours": return "Syllabus • Office Hours"
                case "grading_policy": return "Syllabus • Grading"
                case "important_dates": return "Syllabus • Important Dates"
                case "course_policies": return "Syllabus • Policies"
                default: return "Syllabus"
                }
            }
            return "Syllabus"
        default:
            return "Result"
        }
    }
    
    @MainActor
    private func runSearch() async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        isSearching = true
        errorMessage = nil
        do {
            results = try await APIClient.shared.globalSearch(query: q)
        } catch is CancellationError {
        } catch {
            if !Task.isCancelled {
                errorMessage = (error as? APIError)?.localizedDescription ?? "Something went wrong. Please try again later."
            }
        }
        isSearching = false
    }
    
    private func handleTap(result r: APIClient.GlobalSearchResult) {
        switch r.type {
        case "syllabus":
            if let field = r.field, !r.classId.isEmpty {
                syllabusClassId = r.classId
                syllabusClassCode = r.classCode ?? r.classId
                syllabusField = field
                pushSyllabus = true
            } 
        case "chat":
            guard !r.classId.isEmpty else { return }
            chatClassId = r.classId
            chatClassCode = r.classCode ?? r.classId
            pushChat = true
        default:
            break
        }
    }
    
    // Network fetch helpers no longer needed since results include class_code
}

