import SwiftUI

struct MainTabView: View {
    @Bindable var authViewModel: AuthViewModel

    var body: some View {
        TabView {
            MyScheduleView()
                .tabItem {
                    Label("Schedule", systemImage: "calendar")
                }

            ForumCourseListView()
                .tabItem {
                    Label("Forum", systemImage: "bubble.left.and.bubble.right")
                }

            ProfileView(authViewModel: authViewModel)
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
        }
    }
}

struct ProfileView: View {
    @Bindable var authViewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let user = authViewModel.currentUser {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(.gray)
                            VStack(alignment: .leading) {
                                Text(user.displayName ?? "No name")
                                    .font(.headline)
                                Text(user.email ?? "No email")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }

                Section {
                    Button("Sign Out", role: .destructive) {
                        authViewModel.signOut()
                    }
                }
            }
            .navigationTitle("Profile")
        }
    }
}

#Preview {
    MainTabView(authViewModel: AuthViewModel())
}
