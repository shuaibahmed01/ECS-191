import SwiftUI
import FirebaseAuth

struct MyScheduleView: View {
    @State private var viewModel = MyScheduleViewModel()
    @State private var showingAddClass = false

    private var greeting: String {
        if let name = Auth.auth().currentUser?.displayName, !name.isEmpty {
            return "Hi, \(name)"
        }
        return "My Schedule"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Group {
                    if viewModel.isLoading {
                        ProgressView("Loading schedule...")
                    } else if viewModel.enrolledClasses.isEmpty {
                        ContentUnavailableView(
                            "No Classes",
                            systemImage: "calendar.badge.plus",
                            description: Text("Tap + to add classes")
                        )
                    } else {
                        List(viewModel.enrolledClasses) { entry in
                            NavigationLink {
                                ClassDetailView(entry: entry)
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

                // Floating Add Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            showingAddClass = true
                        } label: {
                            HStack {
                                Image(systemName: "plus")
                                Text("Add Class")
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .background(Color.blue)
                            .clipShape(Capsule())
                            .shadow(radius: 4)
                        }
                        Spacer()
                    }
                    .padding(.bottom, 16)
                }
            }
            .navigationTitle("My Schedule")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(greeting)
                        .font(.headline)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        NavigationLink {
                            UpcomingDatesView()
                        } label: {
                            Image(systemName: "bell.fill")
                        }
                        NavigationLink {
                            GlobalSearchView()
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
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
