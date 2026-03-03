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
            // Prominent Group Chat callout for better discoverability
            Section {
                NavigationLink {
                    ChatView(classId: entry.id, classCode: entry.classCode)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Open Class Group Chat")
                                .font(.headline)
                            Text("Chat with classmates, ask questions, share resources")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 6)
                }
            }

            Section {
                HStack(spacing: 12) {
                    Image(systemName: "book.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                        .frame(width: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.classCode)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(entry.className)
                            .font(.headline)
                    }
                }
                .padding(.vertical, 4)

                if let quarter = entry.quarter {
                    HStack(spacing: 12) {
                        Image(systemName: "calendar")
                            .font(.title2)
                            .foregroundStyle(.orange)
                            .frame(width: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Quarter")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(quarter)
                                .font(.subheadline)
                        }
                    }
                }

                if let times = lectureSummary {
                    HStack(spacing: 12) {
                        Image(systemName: "clock.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                            .frame(width: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Lecture")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(times)
                                .font(.subheadline)
                        }
                    }
                }
            }

            Section {
                NavigationLink {
                    CourseInsightsView(classId: entry.id, classCode: entry.classCode)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "lightbulb.fill")
                            .font(.title2)
                            .foregroundStyle(.yellow)
                            .frame(width: 36)
                        Text("Course Insights")
                    }
                }
            }

            

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

                NavigationLink {
                    SlidesView(classId: entry.id, classCode: entry.classCode)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "rectangle.stack.fill")
                            .font(.title2)
                            .foregroundStyle(.teal)
                            .frame(width: 36)
                        Text("Lecture Slides")
                    }
                }

                NavigationLink {
                    CourseAgentView(classId: entry.id, classCode: entry.classCode)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.title2)
                            .foregroundStyle(.purple)
                            .frame(width: 36)
                        Text("Course Agent")
                    }
                }
            }

            // Destructive action to remove class (more discoverable than swipe)
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
                        removeError = error.localizedDescription
                    }
                    isRemoving = false
                }
            }
            Button("Cancel", role: .cancel) {}
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
