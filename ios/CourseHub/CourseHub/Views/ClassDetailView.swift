import SwiftUI

struct ClassDetailView: View {
    let entry: UserScheduleEntry
    @State private var showSyllabusSheet = false
    @State private var isRemoving = false
    @State private var showRemoveConfirm = false
    @State private var removeError: String?
    @State private var syllabusVM: SyllabusUploadViewModel?
    @State private var remindersVM = RemindersViewModel()
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

            // Important Dates section
            Section("Important Dates") {
                if let vm = syllabusVM, let dates = vm.syllabusContext?.parsedDates, !dates.isEmpty {
                    ForEach(Array(dates.enumerated()), id: \.offset) { idx, parsed in
                        let dateId = "\(entry.id)_\(idx)"
                        let importantDate = ImportantDate(
                            id: dateId,
                            classId: entry.id,
                            classCode: entry.classCode,
                            title: parsed.title,
                            date: parsed.date,
                            description: parsed.description
                        )
                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: 8) {
                                if !parsed.description.isEmpty {
                                    Text(parsed.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                DatePicker(
                                    "Event Date",
                                    selection: Binding(
                                        get: {
                                            remindersVM.effectiveParsedDate(for: importantDate) ?? Date()
                                        },
                                        set: { newDate in
                                            remindersVM.updateEventDate(for: importantDate, newDate: newDate)
                                        }
                                    ),
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.compact)
                                .font(.subheadline)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Remind me")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Picker("", selection: Binding(
                                        get: { remindersVM.reminders[dateId]?.reminderTime ?? .dayBefore },
                                        set: { newTime in
                                            remindersVM.updateReminderTime(for: importantDate, time: newTime)
                                        }
                                    )) {
                                        ForEach(ReminderTime.allCases, id: \.self) { time in
                                            Text(time.displayName).tag(time)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                }
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(parsed.title)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text(formattedDate(remindersVM.reminders[dateId]?.customDate ?? parsed.date))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { remindersVM.reminders[dateId]?.reminderEnabled ?? false },
                                    set: { _ in
                                        Task { await remindersVM.toggleReminder(for: importantDate) }
                                    }
                                ))
                                .labelsHidden()
                            }
                        }
                    }
                } else if syllabusVM == nil || !((syllabusVM?.hasExistingSyllabus) ?? false) {
                    Text("Upload a syllabus to see dates")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No dates found in syllabus")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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
        .sheet(isPresented: $showSyllabusSheet, onDismiss: {
            Task {
                await syllabusVM?.loadExistingSyllabus()
            }
        }) {
            SyllabusUploadView(classId: entry.id, classCode: entry.classCode)
        }
        .navigationTitle(entry.classCode)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: .constant(removeError != nil)) {
            Button("OK") { removeError = nil }
        } message: {
            Text(removeError ?? "")
        }
        .task {
            let vm = SyllabusUploadViewModel(classId: entry.id)
            syllabusVM = vm
            await vm.loadExistingSyllabus()
            remindersVM.reminders = ReminderStore.shared.loadAll()
        }
        .alert("Notifications Disabled", isPresented: $remindersVM.permissionDenied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enable notifications in Settings to receive reminders.")
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

    private func formattedDate(_ dateString: String) -> String {
        let inFormatter = DateFormatter()
        inFormatter.dateFormat = "yyyy-MM-dd"
        guard let date = inFormatter.date(from: dateString) else { return dateString }
        let outFormatter = DateFormatter()
        outFormatter.dateStyle = .medium
        return outFormatter.string(from: date)
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
