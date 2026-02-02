import SwiftUI

struct ClassDetailView: View {
    let entry: UserScheduleEntry

    var body: some View {
        List {
            // Class Information Section
            Section("Class Information") {
                LabeledContent("Code", value: entry.classCode)
                LabeledContent("Name", value: entry.className)
                LabeledContent("Quarter", value: entry.quarter)
            }

            // Chat Section
            Section {
                NavigationLink {
                    ChatView(classId: entry.id, classCode: entry.classCode)
                } label: {
                    Label("Class Group Chat", systemImage: "bubble.left.and.bubble.right.fill")
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
            id: 1,
            classCode: "ECS 032A",
            className: "Introduction to Programming",
            quarter: "W26",
            enrollmentId: 1
        ))
    }
}
