import SwiftUI
import LocalAuthentication
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLocked = true
    @Published var blurSensitiveContent = false
    @Published var authStep: AuthStep = .splash
    @Published var activeTab: TabItem = .portfolio
    @Published var showingAlert: AppAlert?

    enum AuthStep {
        case splash, login, register, twoFactor, biometric, unlocked
    }

    enum TabItem: Int {
        case portfolio, wallets, send, receive, settings
    }

    private let biometricService = BiometricAuthService()
    private let sessionService = SessionService.shared
    private var cancellables = Set<AnyCancellable>()

    func initialize() {
        if sessionService.hasValidSession() {
            authStep = .biometric
            requireBiometricUnlock()
        } else {
            authStep = .login
            isLocked = false
        }
    }

    func lockApp() {
        guard isAuthenticated else { return }
        isLocked = true
        authStep = .biometric
    }

    func requireBiometricUnlock() {
        Task {
            let result = await biometricService.authenticate(reason: "Unlock VaultX")
            if result.success {
                isLocked = false
                authStep = .unlocked
            } else {
                authStep = .login
            }
        }
    }

    func signOut() {
        sessionService.invalidateSession()
        isAuthenticated = false
        isLocked = true
        authStep = .login
    }
}

struct AppAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    var severity: Severity = .info

    enum Severity { case info, warning, critical }
}
