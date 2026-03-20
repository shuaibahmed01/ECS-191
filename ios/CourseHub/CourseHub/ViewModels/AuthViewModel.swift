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

            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = displayName
            try await changeRequest.commitChanges()

            await registerUserWithBackend(user: result.user, displayName: displayName)
        } catch {
            await MainActor.run {
                self.errorMessage = Self.friendlyAuthError(error)
            }
        }
    }

    func signIn(email: String, password: String) async {
        errorMessage = nil

        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)

            await registerUserWithBackend(
                user: result.user,
                displayName: result.user.displayName ?? ""
            )
        } catch {
            await MainActor.run {
                self.errorMessage = Self.friendlyAuthError(error)
            }
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            errorMessage = "Unable to sign out. Please try again."
        }
    }

    func resetPassword(email: String) async {
        errorMessage = nil

        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        } catch {
            await MainActor.run {
                self.errorMessage = Self.friendlyAuthError(error)
            }
        }
    }

    private func registerUserWithBackend(user: User, displayName: String) async {
        do {
            try await APIClient.shared.registerUser(
                uid: user.uid,
                email: user.email ?? "",
                displayName: displayName
            )
        } catch {
            // Backend registration failed — not blocking for the user,
            // but log for debugging. It will re-sync on next sign-in.
            print("Failed to register user with backend: \(error)")
        }
    }

    private static func friendlyAuthError(_ error: Error) -> String {
        let nsError = error as NSError
        guard nsError.domain == AuthErrorDomain else {
            return "Something went wrong. Please try again later."
        }
        switch AuthErrorCode(rawValue: nsError.code) {
        case .invalidEmail:
            return "Please enter a valid email address."
        case .emailAlreadyInUse:
            return "An account with this email already exists."
        case .weakPassword:
            return "Password is too weak. Please use at least 6 characters."
        case .wrongPassword, .invalidCredential:
            return "Incorrect email or password."
        case .userNotFound:
            return "No account found with this email."
        case .userDisabled:
            return "This account has been disabled."
        case .tooManyRequests:
            return "Too many attempts. Please try again later."
        case .networkError:
            return "Unable to connect. Please check your internet connection."
        default:
            return "Something went wrong. Please try again later."
        }
    }
}
