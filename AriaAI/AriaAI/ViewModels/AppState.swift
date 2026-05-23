import SwiftUI
import Combine

enum AppTab: Int, CaseIterable {
    case chat, blocks, inbox, morning, settings

    var title: String {
        switch self {
        case .chat:    return "Chat"
        case .blocks:  return "Blocks"
        case .inbox:   return "Inbox"
        case .morning: return "Briefing"
        case .settings:return "Settings"
        }
    }
    var icon: String {
        switch self {
        case .chat:    return "message.fill"
        case .blocks:  return "puzzlepiece.extension.fill"
        case .inbox:   return "tray.full.fill"
        case .morning: return "sun.horizon.fill"
        case .settings:return "gearshape.fill"
        }
    }
}

@MainActor
class AppState: ObservableObject {
    static let shared = AppState()

    @Published var hasCompletedOnboarding: Bool
    @Published var userName: String

    @Published var showPricingSheet   = false
    @Published var showErrorAlert     = false
    @Published var errorMessage       = ""
    @Published var showUpgradePrompt  = false

    let tokenTracker    = TokenTracker.shared
    let emailService    = EmailService.shared
    let voiceService    = VoiceService.shared
    let purchaseService = PurchaseService.shared
    let briefingService = MorningBriefingService.shared
    let authService     = AuthService.shared

    private init() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.onboardingDone)
        userName = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.userName) ?? "there"

        // Restore StoreKit subscription state on every launch
        Task {
            await purchaseService.updateCurrentPlan()
            // Refresh daily token reset in case app was backgrounded past 8 AM
            tokenTracker.refreshReset()
        }
    }

    func completeOnboarding(name: String) {
        let trimmed = name.trimmed
        userName = trimmed.isEmpty ? (authService.displayName.components(separatedBy: " ").first ?? "there") : trimmed
        UserDefaults.standard.set(userName, forKey: Constants.UserDefaultsKeys.userName)
        UserDefaults.standard.set(true,     forKey: Constants.UserDefaultsKeys.onboardingDone)
        hasCompletedOnboarding = true
    }

    func showError(_ message: String) {
        errorMessage  = message
        showErrorAlert = true
    }

    func triggerUpgradePrompt() {
        showUpgradePrompt = true
    }

    var apiKeySet: Bool { !AuthService.shared.apiKey.isEmpty }
    var plan: SubscriptionPlan { tokenTracker.plan }
}
