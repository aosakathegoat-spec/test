import SwiftUI

struct AuthView: View {
    @EnvironmentObject var appState: AppState
    @State private var isLogin = true
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showPasswordStrength = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        // Logo
                        VStack(spacing: 8) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(
                                    LinearGradient(colors: [.purple, .blue], startPoint: .top, endPoint: .bottom)
                                )
                            Text("VaultX")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 60)

                        // Toggle
                        HStack(spacing: 0) {
                            TabButton(title: "Sign In", isSelected: isLogin) { isLogin = true }
                            TabButton(title: "Create Account", isSelected: !isLogin) { isLogin = false }
                        }
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        // Form
                        VStack(spacing: 16) {
                            SecureTextField(
                                icon: "envelope.fill",
                                placeholder: "Email",
                                text: $email,
                                keyboardType: .emailAddress,
                                isSecure: false
                            )

                            SecureTextField(
                                icon: "lock.fill",
                                placeholder: "Password",
                                text: $password,
                                isSecure: true
                            )
                            .onChange(of: password) { _ in showPasswordStrength = !isLogin }

                            if showPasswordStrength && !isLogin {
                                PasswordStrengthView(password: password)
                                    .transition(.opacity)
                            }

                            if !isLogin {
                                SecureTextField(
                                    icon: "lock.fill",
                                    placeholder: "Confirm Password",
                                    text: $confirmPassword,
                                    isSecure: true
                                )
                            }
                        }

                        // Error
                        if let error = errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text(error)
                                    .font(.caption)
                            }
                            .foregroundColor(.red)
                            .padding(.horizontal)
                        }

                        // Action Button
                        Button(action: handleAuth) {
                            ZStack {
                                if isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(isLogin ? "Sign In" : "Create Account")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(isLoading || !isFormValid)
                        .opacity(isFormValid ? 1 : 0.5)

                        // Security notice
                        VStack(spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.shield.fill")
                                    .foregroundColor(.green)
                                Text("End-to-end encrypted")
                            }
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.shield.fill")
                                    .foregroundColor(.green)
                                Text("Keys never leave your device")
                            }
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.shield.fill")
                                    .foregroundColor(.green)
                                Text("2FA & biometric protection available")
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var isFormValid: Bool {
        let emailValid = email.contains("@") && email.contains(".")
        let passwordValid = password.count >= 8
        if isLogin { return emailValid && passwordValid }
        return emailValid && passwordValid
            && confirmPassword == password
            && PasswordStrengthCalculator.score(password) >= 2
    }

    private func handleAuth() {
        errorMessage = nil
        isLoading = true

        Task {
            do {
                if isLogin {
                    try await signIn()
                } else {
                    try await register()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func signIn() async throws {
        // In production: call authentication API
        try await Task.sleep(nanoseconds: 1_000_000_000)
        await MainActor.run {
            isLoading = false
            appState.isAuthenticated = true
            appState.authStep = .twoFactor
        }
    }

    private func register() async throws {
        guard PasswordStrengthCalculator.score(password) >= 2 else {
            throw AuthError.weakPassword
        }
        try await Task.sleep(nanoseconds: 1_000_000_000)
        await MainActor.run {
            isLoading = false
            appState.isAuthenticated = true
            appState.authStep = .unlocked
        }
    }
}

// MARK: - Two Factor View

struct TwoFactorView: View {
    @EnvironmentObject var appState: AppState
    @State private var code = ""
    @State private var isLoading = false
    @State private var error: String?
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 32) {
                Image(systemName: "lock.circle.fill")
                    .font(.system(size: 70))
                    .foregroundStyle(
                        LinearGradient(colors: [.purple, .blue], startPoint: .top, endPoint: .bottom)
                    )

                VStack(spacing: 8) {
                    Text("Two-Factor Authentication")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    Text("Enter the 6-digit code from your authenticator app")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }

                // OTP Input
                OTPInputView(code: $code, length: 6)
                    .focused($focused)
                    .onChange(of: code) { newCode in
                        if newCode.count == 6 { verifyCode() }
                    }

                if let error {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                Button("Use Backup Code") {
                    // Show backup code input
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            .padding(32)
        }
        .onAppear { focused = true }
        .preferredColorScheme(.dark)
    }

    private func verifyCode() {
        isLoading = true
        Task {
            let valid = TwoFactorAuthService.shared.verify(code: code, secret: "stored_secret")
            await MainActor.run {
                isLoading = false
                if valid {
                    appState.authStep = .unlocked
                } else {
                    error = "Invalid code. Please try again."
                    code = ""
                }
            }
        }
    }
}

// MARK: - Biometric Unlock View

struct BiometricUnlockView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingPasswordFallback = false

    private let biometric = BiometricAuthService()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 32) {
                Image(systemName: biometric.isFaceIDAvailable ? "faceid" : "touchid")
                    .font(.system(size: 80))
                    .foregroundColor(.purple)

                Text("Unlock VaultX")
                    .font(.title2.bold())
                    .foregroundColor(.white)

                Text("Use \(biometric.biometryName) to unlock")
                    .font(.subheadline)
                    .foregroundColor(.gray)

                Button("Use \(biometric.biometryName)") {
                    appState.requireBiometricUnlock()
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)

                Button("Use Passcode Instead") {
                    showingPasswordFallback = true
                }
                .foregroundColor(.gray)
                .font(.subheadline)
            }
        }
        .onAppear { appState.requireBiometricUnlock() }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Reusable Components

struct SecureTextField: View {
    var icon: String
    var placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 20)

            if isSecure {
                SecureField(placeholder, text: $text)
                    .autocorrectionDisabled()
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }
        .padding()
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .foregroundColor(.white)
    }
}

struct TabButton: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : .gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? Color.purple.opacity(0.5) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(4)
        }
    }
}

struct OTPInputView: View {
    @Binding var code: String
    var length: Int

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<length, id: \.self) { i in
                let char = i < code.count ? String(Array(code)[i]) : ""
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.07))
                        .frame(width: 48, height: 56)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(i == code.count ? Color.purple : Color.white.opacity(0.1), lineWidth: 2)
                        )
                    Text(char)
                        .font(.title2.bold())
                        .foregroundColor(.white)
                }
            }
        }
        .overlay(
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textInputAutocapitalization(.never)
                .opacity(0.01)
                .onChange(of: code) { newValue in
                    code = String(newValue.filter(\.isNumber).prefix(length))
                }
        )
    }
}

// MARK: - Password Strength

struct PasswordStrengthView: View {
    var password: String

    var body: some View {
        let score = PasswordStrengthCalculator.score(password)
        let label = ["Too Weak", "Weak", "Fair", "Strong", "Very Strong"][min(score, 4)]
        let color: Color = [.red, .orange, .yellow, .green, .green][min(score, 4)]

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                ForEach(0..<4, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i < score ? color : Color.white.opacity(0.1))
                        .frame(height: 4)
                }
            }
            Text(label)
                .font(.caption)
                .foregroundColor(color)
        }
    }
}

enum PasswordStrengthCalculator {
    static func score(_ password: String) -> Int {
        var score = 0
        if password.count >= 8 { score += 1 }
        if password.count >= 12 { score += 1 }
        if password.contains(where: { $0.isUppercase }) { score += 1 }
        if password.contains(where: { $0.isNumber }) { score += 1 }
        if password.contains(where: { "!@#$%^&*()_+-=[]{}|;':\",./<>?".contains($0) }) { score += 1 }
        return min(score, 4)
    }
}

enum AuthError: LocalizedError {
    case weakPassword
    case invalidCredentials
    case emailTaken

    var errorDescription: String? {
        switch self {
        case .weakPassword: return "Password is too weak. Use 12+ characters with mixed case, numbers, and symbols."
        case .invalidCredentials: return "Invalid email or password"
        case .emailTaken: return "An account with this email already exists"
        }
    }
}
