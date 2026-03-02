import SwiftUI

struct CourseInsightsView: View {
    let classId: String
    let classCode: String

    @State private var syllabusContext: SyllabusContext?
    @State private var isLoading = false
    @State private var expandedCard: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading insights...")
            } else if let context = syllabusContext {
                List {
                    insightSection(title: "Instructor", content: context.instructor, icon: "person.fill", color: .blue, id: "instructor")
                    insightSection(title: "Office Hours", content: context.officeHours, icon: "clock.fill", color: .green, id: "officeHours")
                    insightSection(title: "Grading Policy", content: context.gradingPolicy, icon: "chart.bar.fill", color: .orange, id: "gradingPolicy")
                    insightSection(title: "Important Dates", content: context.importantDates, icon: "calendar", color: .red, id: "importantDates")
                    insightSection(title: "Course Policies", content: context.coursePolicies, icon: "list.clipboard.fill", color: .purple, id: "coursePolicies")
                }
            } else {
                ContentUnavailableView {
                    Label("No Syllabus", systemImage: "doc.text.magnifyingglass")
                } description: {
                    Text("Upload a syllabus to see course insights.")
                }
            }
        }
        .navigationTitle("Course Insights")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadSyllabus()
        }
        .sheet(item: $expandedCard) { cardId in
            SyllabusCardDetailSheet(
                cardId: cardId,
                syllabusContext: syllabusContext
            )
        }
    }

    private func loadSyllabus() async {
        isLoading = true
        do {
            let response = try await APIClient.shared.getSyllabusContext(classId: classId)
            syllabusContext = response.syllabus
        } catch {
            syllabusContext = nil
        }
        isLoading = false
    }

    private func insightSection(title: String, content: String, icon: String, color: Color, id: String) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .foregroundStyle(color)
                    Text(title)
                        .font(.headline)
                }
                Text(content.markdownFormatted)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .onTapGesture {
                expandedCard = id
            }
        }
    }
}
