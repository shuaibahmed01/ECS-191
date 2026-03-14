import SwiftUI

struct UpcomingDatesView: View {
    @State private var viewModel = RemindersViewModel()
    @State private var expandedDateId: String?

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading dates...")
            } else if viewModel.upcomingDates.isEmpty {
                ContentUnavailableView(
                    "No Important Dates",
                    systemImage: "calendar",
                    description: Text("Upload syllabi to see upcoming dates.")
                )
            } else {
                List {
                    ForEach(viewModel.datesByMonth, id: \.0) { month, dates in
                        Section(month) {
                            ForEach(dates) { date in
                                dateRow(date)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Upcoming Dates")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadDates()
        }
        .refreshable {
            await viewModel.loadDates()
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert("Notifications Disabled", isPresented: $viewModel.permissionDenied) {
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
                    HStack(spacing: 8) {
                        Text(date.classCode)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.12))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                        Text(formattedDate(date.date))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { viewModel.reminders[date.id]?.reminderEnabled ?? false },
                    set: { _ in
                        Task { await viewModel.toggleReminder(for: date) }
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

                if viewModel.reminders[date.id]?.reminderEnabled == true {
                    Picker("Remind", selection: Binding(
                        get: { viewModel.reminders[date.id]?.reminderTime ?? .dayBefore },
                        set: { newTime in
                            viewModel.updateReminderTime(for: date, time: newTime)
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
        UpcomingDatesView()
    }
}
