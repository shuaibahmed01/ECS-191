import SwiftUI

struct LoginView: View {
    @Bindable var authViewModel: AuthViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isSignUp = false
    @State private var showForgotPassword = false
    @State private var forgotPasswordEmail = ""
    @State private var showResetConfirmation = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Logo/Title
                VStack(spacing: 8) {
                    Image(systemName: "book.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.blue)

                    Text("CourseHub")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text(isSignUp ? "Create your account" : "Sign in to continue")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)

                // Form fields
                VStack(spacing: 16) {
                    if isSignUp {
                        TextField("Display Name", text: $displayName)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.name)
                            .autocorrectionDisabled()
                    }

                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(isSignUp ? .newPassword : .password)
                }
                .padding(.horizontal, 24)

                // Error message
                if let error = authViewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        Task {
                            if isSignUp {
                                await authViewModel.signUp(
                                    email: email,
                                    password: password,
                                    displayName: displayName
                                )
                            } else {
                                await authViewModel.signIn(email: email, password: password)
                            }
                        }
                    } label: {
                        Text(isSignUp ? "Sign Up" : "Sign In")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .cornerRadius(10)
                    }
                    .disabled(!isFormValid)
                    .opacity(isFormValid ? 1 : 0.6)

                    if !isSignUp {
                        Button("Forgot Password?") {
                            forgotPasswordEmail = email
                            showForgotPassword = true
                        }
                        .font(.subheadline)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                // Toggle sign up/sign in
                HStack {
                    Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                        .foregroundStyle(.secondary)
                    Button(isSignUp ? "Sign In" : "Sign Up") {
                        withAnimation {
                            isSignUp.toggle()
                            authViewModel.errorMessage = nil
                        }
                    }
                    .fontWeight(.semibold)
                }
                .font(.subheadline)
                .padding(.bottom, 24)
            }
            .alert("Reset Password", isPresented: $showForgotPassword) {
                TextField("Email", text: $forgotPasswordEmail)
                Button("Cancel", role: .cancel) { }
                Button("Send Reset Link") {
                    Task {
                        await authViewModel.resetPassword(email: forgotPasswordEmail)
                        showResetConfirmation = true
                    }
                }
            } message: {
                Text("Enter your email address and we'll send you a link to reset your password.")
            }
            .alert("Check Your Email", isPresented: $showResetConfirmation) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("If an account exists for \(forgotPasswordEmail), you'll receive a password reset link shortly.")
            }
        }
    }

    private var isFormValid: Bool {
        if isSignUp {
            return !email.isEmpty && !password.isEmpty && !displayName.isEmpty && password.count >= 6
        } else {
            return !email.isEmpty && !password.isEmpty
        }
    }
}

#Preview {
    LoginView(authViewModel: AuthViewModel())
}
