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
            ScrollView {
                VStack(spacing: 32) {
                    Spacer().frame(height: 40)

                    // Logo
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.gradient)
                                .frame(width: 88, height: 88)
                            Image(systemName: "book.fill")
                                .font(.system(size: 38))
                                .foregroundStyle(.white)
                        }

                        Text("CourseHub")
                            .font(.largeTitle.bold())

                        Text(isSignUp ? "Create your account" : "Sign in to continue")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Form
                    VStack(spacing: 14) {
                        if isSignUp {
                            HStack(spacing: 12) {
                                Image(systemName: "person")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)
                                TextField("Display Name", text: $displayName)
                                    .textContentType(.name)
                                    .autocorrectionDisabled()
                            }
                            .padding(14)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        HStack(spacing: 12) {
                            Image(systemName: "envelope")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            TextField("Email", text: $email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        .padding(14)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        HStack(spacing: 12) {
                            Image(systemName: "lock")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            SecureField("Password", text: $password)
                                .textContentType(isSignUp ? .newPassword : .password)
                        }
                        .padding(14)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 24)

                    // Error
                    if let error = authViewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    // Buttons
                    VStack(spacing: 14) {
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
                                .padding(.vertical, 16)
                                .background(isFormValid ? Color.blue.gradient : Color.gray.opacity(0.3).gradient)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(!isFormValid)

                        if !isSignUp {
                            Button("Forgot Password?") {
                                forgotPasswordEmail = email
                                showForgotPassword = true
                            }
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer()

                    // Toggle
                    HStack(spacing: 4) {
                        Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                            .foregroundStyle(.secondary)
                        Button(isSignUp ? "Sign In" : "Sign Up") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isSignUp.toggle()
                                authViewModel.errorMessage = nil
                            }
                        }
                        .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .padding(.bottom, 24)
                }
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
