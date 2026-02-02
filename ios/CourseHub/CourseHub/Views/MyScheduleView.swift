import SwiftUI

struct MyScheduleView: View {
    @State private var viewModel = MyScheduleViewModel()
    @State private var showingAddClass = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading schedule...")
                } else if viewModel.enrolledClasses.isEmpty {
                    ContentUnavailableView(
                        "No Classes",
                        systemImage: "calendar.badge.plus",
                        description: Text("Tap the button below to add classes")
                    )
                } else {
                    List(viewModel.enrolledClasses) { entry in
                        NavigationLink {
                            // Placeholder for class detail view
                            Text("Class detail for \(entry.classCode)")
                        } label: {
                            VStack(alignment: .leading) {
                                Text(entry.classCode)
                                    .font(.headline)
                                Text(entry.className)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task {
                                    await viewModel.removeClass(enrollmentId: entry.enrollmentId)
                                }
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("My Schedule")
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        showingAddClass = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Class")
                        }
                        .font(.headline)
                    }
                }
            }
            .sheet(isPresented: $showingAddClass) {
                ClassListView(
                    enrolledClassIds: Set(viewModel.enrolledClasses.map { $0.id }),
                    onClassAdded: {
                        Task {
                            await viewModel.loadSchedule()
                        }
                    }
                )
            }
            .task {
                await viewModel.loadSchedule()
            }
            .refreshable {
                await viewModel.loadSchedule()
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil && !viewModel.isLoading)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}

#Preview {
    MyScheduleView()
}
