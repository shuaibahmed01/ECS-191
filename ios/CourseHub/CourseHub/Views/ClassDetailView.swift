import SwiftUI

struct ClassDetailView: View {
    let entry: UserScheduleEntry
    @State private var showSyllabusSheet = false
    @State private var isRemoving = false
    @State private var showRemoveConfirm = false
    @State private var removeError: String?
    @Environment(\.dismiss) private var dismiss

    private var lectureSummary: String? {
        guard let times = entry.lectureTimes, !times.isEmpty else { return nil }
        return times.joined(separator: ", ")
    }

    var body: some View {
        List {
            // Group Chat
            Section {
                NavigationLink {
                    ChatView(classId: entry.id, classCode: entry.classCode)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.blue.gradient)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Group Chat")
                                .font(.headline)
                            Text("Chat with classmates")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }

            // Class Info
            Section {
                infoRow(icon: "book.fill", color: .blue) {
                    Text(entry.classCode)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(entry.className)
                        .font(.headline)
                }

                if let quarter = entry.quarter {
                    infoRow(icon: "calendar", color: .orange) {
                        Text("Quarter")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(quarter)
                            .font(.subheadline)
                    }
                }

                if let times = lectureSummary {
                    infoRow(icon: "clock.fill", color: .green) {
                        Text("Lecture")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(times)
                            .font(.subheadline)
                    }
                }
            }

            // Quick Links
            Section {
                navRow(icon: "bell.fill", color: .red, title: "Reminders") {
                    ClassRemindersView(classId: entry.id, classCode: entry.classCode)
                }
                navRow(icon: "lightbulb.fill", color: .yellow, title: "Course Insights") {
                    CourseInsightsView(classId: entry.id, classCode: entry.classCode)
                }
            }

            // Syllabus & AI
            Section("Syllabus & AI") {
                Button {
                    showSyllabusSheet = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.text.fill")
                            .font(.title2)
                            .foregroundStyle(.orange)
                            .frame(width: 36)
                        Text("Syllabus")
                            .foregroundStyle(.primary)
                    }
                }

                navRow(icon: "rectangle.stack.fill", color: .teal, title: "Lecture Slides") {
                    SlidesView(classId: entry.id, classCode: entry.classCode)
                }
                navRow(icon: "sparkles", color: .purple, title: "Course Agent") {
                    CourseAgentView(classId: entry.id, classCode: entry.classCode)
                }
                navRow(icon: "doc.questionmark.fill", color: .indigo, title: "Practice Exams") {
                    PracticeExamsView(classId: entry.id, classCode: entry.classCode)
                }
            }

            // Remove
            Section {
                Button(role: .destructive) {
                    showRemoveConfirm = true
                } label: {
                    HStack {
                        Spacer()
                        if isRemoving {
                            ProgressView()
                        } else {
                            Text("Remove from Schedule")
                        }
                        Spacer()
                    }
                }
                .disabled(isRemoving)
            }
        }
        .sheet(isPresented: $showSyllabusSheet) {
            SyllabusUploadView(classId: entry.id, classCode: entry.classCode)
        }
        .navigationTitle(entry.classCode)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: .constant(removeError != nil)) {
            Button("OK") { removeError = nil }
        } message: {
            Text(removeError ?? "")
        }
        .confirmationDialog(
            "Remove \(entry.classCode) from your schedule?",
            isPresented: $showRemoveConfirm,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                Task {
                    isRemoving = true
                    do {
                        try await APIClient.shared.unenroll(enrollmentId: entry.enrollmentId)
                        dismiss()
                    } catch {
                        removeError = (error as? APIError)?.localizedDescription ?? "Something went wrong. Please try again later."
                    }
                    isRemoving = false
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Helpers

    private func infoRow<Content: View>(icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                content()
            }
        }
        .padding(.vertical, 4)
    }

    private func navRow<Destination: View>(icon: String, color: Color, title: String, @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 36)
                Text(title)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ClassDetailView(entry: UserScheduleEntry(
            id: "ecs_032a",
            classCode: "ECS 032A",
            className: "Introduction to Programming",
            quarter: "W26",
            enrollmentId: "1",
            lectureTimes: ["6:10 - 7:30 PM, MW"],
            discussionTimes: ["9:00 - 9:50 AM, F", "10:00 - 10:50 AM, F"]
        ))
    }
}
