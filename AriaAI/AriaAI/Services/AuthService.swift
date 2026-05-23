import Foundation
import AuthenticationServices
import SwiftUI

enum LoginProvider: String, Codable {
    case apple, google
}

@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published var isLoggedIn    = false
    @Published var hasEnteredAge = false
    @Published var provider: LoginProvider?
    @Published var displayName   = ""
    @Published var userEmail     = ""
    @Published var isSigningIn   = false
    @Published var authError: String?

    // DOB components
    @Published var birthMonth: Int = 6
    @Published var birthDay:   Int = 15
    @Published var birthYear:  Int = 1995

    private enum Keys {
        static let userID      = "aria_auth_user_id"      // keychain
        static let apiKey      = "aria_api_key"            // keychain — moved from UserDefaults
        static let provider    = "aria_auth_provider"
        static let name        = "aria_auth_name"
        static let email       = "aria_auth_email"
        static let hasAge      = "aria_has_age"
        static let birthMonth  = "aria_birth_month"
        static let birthDay    = "aria_birth_day"
        static let birthYear   = "aria_birth_year"
    }

    private init() { loadState() }

    // MARK: - Sign in with Apple
    func handleAppleCredential(_ credential: ASAuthorizationAppleIDCredential) {
        let id   = credential.user
        let name = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }.joined(separator: " ")

        KeychainService.set(id, for: Keys.userID)
        UserDefaults.standard.set(LoginProvider.apple.rawValue, forKey: Keys.provider)
        // Only persist name/email if Apple provides them (only on first sign-in)
        if !name.isEmpty {
            UserDefaults.standard.set(name, forKey: Keys.name)
            displayName = name
        }
        if let email = credential.email {
            UserDefaults.standard.set(email, forKey: Keys.email)
            userEmail = email
        }

        provider    = .apple
        isLoggedIn  = true
        isSigningIn = false
    }

    func handleAppleError(_ error: Error) {
        let asError = error as? ASAuthorizationError
        if asError?.code == .canceled { isSigningIn = false; return }
        authError   = error.localizedDescription
        isSigningIn = false
    }

    // MARK: - Sign in with Google
    func signInWithGoogle(id: String, name: String, email: String) {
        KeychainService.set(id, for: Keys.userID)
        UserDefaults.standard.set(LoginProvider.google.rawValue, forKey: Keys.provider)
        UserDefaults.standard.set(name,  forKey: Keys.name)
        UserDefaults.standard.set(email, forKey: Keys.email)

        displayName = name
        userEmail   = email
        provider    = .google
        isLoggedIn  = true
        isSigningIn = false
    }

    // MARK: - Age
    func saveAge() {
        UserDefaults.standard.set(birthMonth, forKey: Keys.birthMonth)
        UserDefaults.standard.set(birthDay,   forKey: Keys.birthDay)
        UserDefaults.standard.set(birthYear,  forKey: Keys.birthYear)
        UserDefaults.standard.set(true,       forKey: Keys.hasAge)
        hasEnteredAge = true
    }

    var age: Int {
        let now        = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        var years      = (now.year ?? 0) - birthYear
        let monthDiff  = (now.month ?? 0) - birthMonth
        if monthDiff < 0 || (monthDiff == 0 && (now.day ?? 0) < birthDay) { years -= 1 }
        return max(0, years)
    }

    var birthDateDisplay: String {
        let months = ["January","February","March","April","May","June",
                      "July","August","September","October","November","December"]
        let m = months[max(0, min(11, birthMonth - 1))]
        return "\(m) \(birthDay), \(birthYear)"
    }

    // MARK: - API Key (migrated to Keychain)
    var apiKey: String {
        get {
            // Migrate from UserDefaults if present
            if let legacy = UserDefaults.standard.string(forKey: "api_key"), !legacy.isEmpty {
                KeychainService.set(legacy, for: Keys.apiKey)
                UserDefaults.standard.removeObject(forKey: "api_key")
                return legacy
            }
            return KeychainService.get(Keys.apiKey) ?? ""
        }
        set {
            KeychainService.set(newValue, for: Keys.apiKey)
            UserDefaults.standard.removeObject(forKey: "api_key")
        }
    }

    // MARK: - Sign Out
    func signOut() {
        // Clear auth credentials
        KeychainService.delete(Keys.userID)
        KeychainService.delete(Keys.apiKey)
        UserDefaults.standard.removeObject(forKey: Keys.provider)
        UserDefaults.standard.removeObject(forKey: Keys.name)
        UserDefaults.standard.removeObject(forKey: Keys.email)
        UserDefaults.standard.removeObject(forKey: Keys.hasAge)
        UserDefaults.standard.removeObject(forKey: Keys.birthMonth)
        UserDefaults.standard.removeObject(forKey: Keys.birthDay)
        UserDefaults.standard.removeObject(forKey: Keys.birthYear)
        // Disconnect Gmail so the next user starts fresh
        EmailService.shared.disconnect()
        // Clear per-user app data
        UserDefaults.standard.removeObject(forKey: Constants.UserDefaultsKeys.chatSessions)
        UserDefaults.standard.removeObject(forKey: Constants.UserDefaultsKeys.currentSession)
        UserDefaults.standard.removeObject(forKey: Constants.UserDefaultsKeys.userName)
        UserDefaults.standard.removeObject(forKey: Constants.UserDefaultsKeys.onboardingDone)
        UserDefaults.standard.removeObject(forKey: Constants.UserDefaultsKeys.inputTokens)
        UserDefaults.standard.removeObject(forKey: Constants.UserDefaultsKeys.outputTokens)
        UserDefaults.standard.removeObject(forKey: Constants.UserDefaultsKeys.cachedTokens)
        UserDefaults.standard.removeObject(forKey: Constants.UserDefaultsKeys.resetDate)
        UserDefaults.standard.removeObject(forKey: Constants.UserDefaultsKeys.plan)
        isLoggedIn    = false
        hasEnteredAge = false
        provider      = nil
        displayName   = ""
        userEmail     = ""
    }

    // MARK: - Persistence
    private func loadState() {
        guard KeychainService.exists(Keys.userID),
              let provRaw = UserDefaults.standard.string(forKey: Keys.provider),
              let prov    = LoginProvider(rawValue: provRaw)
        else { return }

        provider    = prov
        displayName = UserDefaults.standard.string(forKey: Keys.name)  ?? ""
        userEmail   = UserDefaults.standard.string(forKey: Keys.email) ?? ""
        isLoggedIn  = true
        hasEnteredAge = UserDefaults.standard.bool(forKey: Keys.hasAge)

        if hasEnteredAge {
            birthMonth = UserDefaults.standard.integer(forKey: Keys.birthMonth).clampedMonth
            birthDay   = UserDefaults.standard.integer(forKey: Keys.birthDay).clampedDay
            birthYear  = UserDefaults.standard.integer(forKey: Keys.birthYear).clampedYear
        }
    }
}

private extension Int {
    var clampedMonth: Int { self <= 0 ? 6  : min(12, self) }
    var clampedDay:   Int { self <= 0 ? 15 : min(31, self) }
    var clampedYear:  Int { self <= 0 ? 1995 : min(Calendar.current.component(.year, from: Date()) - 13, self) }
}
