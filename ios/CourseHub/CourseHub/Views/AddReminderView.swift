import SwiftUI

struct AddReminderView: View {
    /// If provided, the reminder is pre-associated with this class.
    var classId: String?
    var classCode: String?

    var onSave: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var eventDate = Date()
    @State private var reminderTime: ReminderTime = .dayBefore
    @State private var description = ""
    @State private var permissionDenied = false

    // For the global view — let user pick a class
    @State private var enrolledClasses: [UserScheduleEntry] = []
    @State private var selectedClassIndex: Int = 0

    private var needsClassPicker: Bool { classId == nil }

    private var resolvedClassId: String {
        if let classId { return classId }
        guard !enrolledClasses.isEmpty else { return "custom" }
        return enrolledClasses[selectedClassIndex].id
    }

    private var resolvedClassCode: String {
        if let classCode { return classCode }
        guard !enrolledClasses.isEmpty else { return "General" }
        return enrolledClasses[selectedClassIndex].classCode
    }

    var body: some View {
        NavigationStack {
            Form {
                if needsClassPicker && !enrolledClasses.isEmpty {
                    Section("Class") {
                        Picker("Class", selection: $selectedClassIndex) {
                            ForEach(enrolledClasses.indices, id: \.self) { index in
                                Text(enrolledClasses[index].classCode).tag(index)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                Section("Details") {
                    TextField("Title", text: $title)
                    TextField("Description (optional)", text: $description)
                }

                Section("When") {
                    DatePicker(
                        "Date & Time",
                        selection: $eventDate,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }

                Section("Remind Me") {
                    Picker("", selection: $reminderTime) {
                        ForEach(ReminderTime.allCases, id: \.self) { time in
                            Text(time.displayName).tag(time)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("New Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveReminder() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .task {
                if needsClassPicker {
                    enrolledClasses = (try? await APIClient.shared.fetchMyClasses()) ?? []
                }
            }
            .alert("Notifications Disabled", isPresented: $permissionDenied) {
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
    }

    private func saveReminder() {
        let dateString = ImportantDate.dateTimeFormatter.string(from: eventDate)
        let id = "custom_\(UUID().uuidString)"

        let importantDate = ImportantDate(
            id: id,
            classId: resolvedClassId,
            classCode: resolvedClassCode,
            title: title.trimmingCharacters(in: .whitespaces),
            date: dateString,
            description: description.trimmingCharacters(in: .whitespaces)
        )

        // Save the custom reminder
        CustomReminderStore.shared.add(importantDate)

        // Create a reminder preference with it enabled
        let pref = ReminderPreference(
            dateId: id,
            classId: resolvedClassId,
            title: importantDate.title,
            date: dateString,
            reminderEnabled: true,
            reminderTime: reminderTime,
            customDate: nil
        )
        ReminderStore.shared.setPreference(pref)

        // Schedule the notification
        Task {
            let granted = await NotificationService.shared.requestPermission()
            if granted {
                NotificationService.shared.scheduleReminder(for: importantDate, time: reminderTime)
            } else {
                permissionDenied = true
                return
            }

            onSave?()
            dismiss()
        }
    }
}
