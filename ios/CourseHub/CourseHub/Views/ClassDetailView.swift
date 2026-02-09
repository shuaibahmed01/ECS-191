import SwiftUI

struct ClassDetailView: View {
    let entry: UserScheduleEntry

    private var lectureSummary: String? {
        guard let times = entry.lectureTimes, !times.isEmpty else { return nil }
        return times.joined(separator: ", ")
    }

    var body: some View {
        List {
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
                    ChatView(classId: entry.id, classCode: entry.classCode)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                            .frame(width: 36)
                        Text("Class Group Chat")
                    }
                }
            }
        }
        .navigationTitle(entry.classCode)
        .navigationBarTitleDisplayMode(.inline)
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
