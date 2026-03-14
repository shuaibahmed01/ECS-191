import SwiftUI
import FirebaseCore

@main
struct CourseHubApp: App {
    @State private var authViewModel: AuthViewModel
    @State private var themeManager = ThemeManager.shared

    init() {
        FirebaseApp.configure()
        _authViewModel = State(initialValue: AuthViewModel())
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isLoading {
                    ProgressView("Loading...")
                } else if authViewModel.isAuthenticated {
                    MainTabView(authViewModel: authViewModel)
                } else {
                    LoginView(authViewModel: authViewModel)
                }
            }
            .preferredColorScheme(themeManager.currentTheme.colorScheme)
        }
    }
}
