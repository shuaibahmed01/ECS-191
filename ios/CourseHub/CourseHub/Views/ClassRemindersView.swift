import SwiftUI

struct ClassRemindersView: View {
    let classId: String
    let classCode: String

    @State private var syllabusVM: SyllabusUploadViewModel?
    @State private var remindersVM = RemindersViewModel()
    @State private var expandedDateId: String?
    @State private var showingAddReminder = false
    @State private var customReminders: [ImportantDate] = []

    private var syllabusDates: [ImportantDate] {
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

    private var allDates: [ImportantDate] {
        syllabusDates + customReminders
    }

    var body: some View {
        Group {
            if syllabusVM == nil {
                ProgressView("Loading...")
            } else if allDates.isEmpty {
                ContentUnavailableView(
                    "No Reminders",
                    systemImage: "bell",
                    description: Text("Upload a syllabus or tap + to create a custom reminder.")
                )
            } else {
                List {
                    if !syllabusDates.isEmpty {
                        Section("From Syllabus") {
                            ForEach(syllabusDates) { date in
                                dateRow(date)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            deleteReminder(date)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                    if !customReminders.isEmpty {
                        Section("Custom") {
                            ForEach(customReminders) { date in
                                dateRow(date)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            deleteReminder(date)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddReminder = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddReminder) {
            AddReminderView(classId: classId, classCode: classCode) {
                customReminders = CustomReminderStore.shared.loadForClass(classId)
                remindersVM.reminders = ReminderStore.shared.loadAll()
            }
        }
        .task {
            let vm = SyllabusUploadViewModel(classId: classId)
            syllabusVM = vm
            await vm.loadExistingSyllabus()
            customReminders = CustomReminderStore.shared.loadForClass(classId)
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
                    Text(formattedDateTime(remindersVM.effectiveDateString(for: date)))
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
                    "Date & Time",
                    selection: Binding(
                        get: { remindersVM.effectiveParsedDate(for: date) ?? Date() },
                        set: { newDate in
                            remindersVM.updateEventDate(for: date, newDate: newDate)
                        }
                    ),
                    displayedComponents: [.date, .hourAndMinute]
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

    private func deleteReminder(_ date: ImportantDate) {
        if date.id.hasPrefix("custom_") {
            CustomReminderStore.shared.remove(id: date.id)
            customReminders.removeAll { $0.id == date.id }
        }
        NotificationService.shared.cancelReminder(dateId: date.id)
        remindersVM.reminders.removeValue(forKey: date.id)
    }

    private func formattedDateTime(_ dateString: String) -> String {
        guard let date = ImportantDate.parseDate(dateString) else { return dateString }
        let formatter = DateFormatter()
        // If the string has time info (custom date), show date + time
        if dateString.contains(" ") {
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
        } else {
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
        }
        return formatter.string(from: date)
    }
}
