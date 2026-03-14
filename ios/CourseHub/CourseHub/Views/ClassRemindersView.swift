import SwiftUI

struct ClassRemindersView: View {
    let classId: String
    let classCode: String

    @State private var syllabusVM: SyllabusUploadViewModel?
    @State private var remindersVM = RemindersViewModel()
    @State private var expandedDateId: String?

    private var dates: [ImportantDate] {
        guard let parsed = syllabusVM?.syllabusContext?.parsedDates else { return [] }
        return parsed.enumerated().map { idx, p in
            ImportantDate(
                id: "\(classId)_\(idx)",
                classId: classId,
                classCode: classCode,
                title: p.title,
                date: p.date,
                description: p.description
            )
        }
    }

    var body: some View {
        Group {
            if syllabusVM == nil {
                ProgressView("Loading...")
            } else if dates.isEmpty {
                ContentUnavailableView(
                    "No Important Dates",
                    systemImage: "calendar",
                    description: Text("Upload a syllabus to see important dates for this class.")
                )
            } else {
                List {
                    ForEach(dates) { date in
                        dateRow(date)
                    }
                }
            }
        }
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let vm = SyllabusUploadViewModel(classId: classId)
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
    }

    @ViewBuilder
    private func dateRow(_ date: ImportantDate) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(date.title)
                        .font(.headline)
                    Text(formattedDate(remindersVM.reminders[date.id]?.customDate ?? date.date))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { remindersVM.reminders[date.id]?.reminderEnabled ?? false },
                    set: { _ in
                        Task { await remindersVM.toggleReminder(for: date) }
                    }
                ))
                .labelsHidden()
            }

            if expandedDateId == date.id {
                if !date.description.isEmpty {
                    Text(date.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                DatePicker(
                    "Event Date",
                    selection: Binding(
                        get: { remindersVM.effectiveParsedDate(for: date) ?? Date() },
                        set: { newDate in
                            remindersVM.updateEventDate(for: date, newDate: newDate)
                        }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Remind me")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Picker("", selection: Binding(
                        get: { remindersVM.reminders[date.id]?.reminderTime ?? .dayBefore },
                        set: { newTime in
                            remindersVM.updateReminderTime(for: date, time: newTime)
                        }
                    )) {
                        ForEach(ReminderTime.allCases, id: \.self) { time in
                            Text(time.displayName).tag(time)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation {
                expandedDateId = expandedDateId == date.id ? nil : date.id
            }
        }
    }

    private func formattedDate(_ dateString: String) -> String {
        guard let date = ImportantDate.dateFormatter.date(from: dateString) else { return dateString }
        let outFormatter = DateFormatter()
        outFormatter.dateStyle = .medium
        return outFormatter.string(from: date)
    }
}
