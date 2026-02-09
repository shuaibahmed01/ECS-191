import SwiftUI
import FirebaseCore

@main
struct CourseHubApp: App {
    @State private var authViewModel: AuthViewModel

    init() {
        // Configure Firebase FIRST, before creating AuthViewModel
        FirebaseApp.configure()

        // Now safe to create AuthViewModel
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
        }
    }
}
