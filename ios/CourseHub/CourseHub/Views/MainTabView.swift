import SwiftUI
import FirebaseAuth

struct MainTabView: View {
    @Bindable var authViewModel: AuthViewModel

    var body: some View {
        TabView {
            MyScheduleView()
                .tabItem {
                    Label("Schedule", systemImage: "calendar")
                }

            ProfileView(authViewModel: authViewModel)
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
        }
        .tint(.blue)
    }
}

struct ProfileView: View {
    @Bindable var authViewModel: AuthViewModel
    @State private var themeManager = ThemeManager.shared

    private var initials: String {
        guard let name = authViewModel.currentUser?.displayName, !name.isEmpty else { return "?" }
        let parts = name.split(separator: " ")
        let first = parts.first.map { String($0.prefix(1)) } ?? ""
        let last = parts.count > 1 ? String(parts.last!.prefix(1)) : ""
        return (first + last).uppercased()
    }

    var body: some View {
        NavigationStack {
            List {
                // Profile header
                Section {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.gradient)
                                .frame(width: 64, height: 64)
                            Text(initials)
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(authViewModel.currentUser?.displayName ?? "No name")
                                .font(.title3.bold())
                            Text(authViewModel.currentUser?.email ?? "")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Appearance
                Section("Appearance") {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Button {
                            withAnimation {
                                themeManager.currentTheme = theme
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: theme.icon)
                                    .font(.body)
                                    .foregroundStyle(theme == themeManager.currentTheme ? .blue : .secondary)
                                    .frame(width: 28)
                                Text(theme.displayName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if theme == themeManager.currentTheme {
                                    Image(systemName: "checkmark")
                                        .font(.body.bold())
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }

                // About
                Section("About") {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }

                // Sign out
                Section {
                    Button(role: .destructive) {
                        authViewModel.signOut()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Sign Out")
                            Spacer()
                        }
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
