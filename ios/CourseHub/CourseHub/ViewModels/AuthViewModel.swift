import Foundation
import FirebaseAuth

@Observable
class AuthViewModel {
    var isAuthenticated = false
    var isLoading = true
    var errorMessage: String?
    var currentUser: User?

    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init() {
        listenToAuthState()
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    private func listenToAuthState() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.currentUser = user
                self?.isAuthenticated = user != nil
                self?.isLoading = false
            }
        }
    }

    func signUp(email: String, password: String, displayName: String) async {
        errorMessage = nil

        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)

            // Set display name
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = displayName
            try await changeRequest.commitChanges()

            // Register user with backend
            await registerUserWithBackend(user: result.user, displayName: displayName)
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func signIn(email: String, password: String) async {
        errorMessage = nil

        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)

            // Sync user info with backend
            await registerUserWithBackend(
                user: result.user,
                displayName: result.user.displayName ?? ""
            )
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resetPassword(email: String) async {
        errorMessage = nil

        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    private func registerUserWithBackend(user: User, displayName: String) async {
        // Register the new user with our backend
        do {
            try await APIClient.shared.registerUser(
                uid: user.uid,
                email: user.email ?? "",
                displayName: displayName
            )
        } catch {
            print("Failed to register user with backend: \(error)")
        }
    }
}
