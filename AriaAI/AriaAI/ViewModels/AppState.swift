import SwiftUI
import Combine

enum AppTab: Int, CaseIterable {
    case chat, inbox, morning, settings
    var title: String {
        switch self {
        case .chat:     return "Chat"
        case .inbox:    return "Inbox"
        case .morning:  return "Briefing"
        case .settings: return "Settings"
        }
    }
    var icon: String {
        switch self {
        case .chat:     return "message.fill"
        case .inbox:    return "tray.full.fill"
        case .morning:  return "sun.horizon.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

@MainActor
class AppState: ObservableObject {
    static let shared = AppState()

    @Published var currentTab: AppTab = .chat
    @Published var hasCompletedOnboarding: Bool
    @Published var userName: String

    @Published var showPricingSheet  = false
    @Published var showErrorAlert    = false
    @Published var errorMessage      = ""
    @Published var showUpgradePrompt = false

    let tokenTracker   = TokenTracker.shared
    let emailService   = EmailService.shared
    let voiceService   = VoiceService.shared
    let purchaseService = PurchaseService.shared
    let briefingService = MorningBriefingService.shared

    private var cancellables = Set<AnyCancellable>()

    private init() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.onboardingDone)
        userName = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.userName) ?? "there"

        // Restore active subscription on launch
        Task { await purchaseService.updateCurrentPlan() }
    }

    func completeOnboarding(name: String) {
        userName = name.trimmed.isEmpty ? "there" : name
        UserDefaults.standard.set(userName, forKey: Constants.UserDefaultsKeys.userName)
        UserDefaults.standard.set(true, forKey: Constants.UserDefaultsKeys.onboardingDone)
        hasCompletedOnboarding = true
    }

    func showError(_ message: String) {
        errorMessage = message
        showErrorAlert = true
    }

    func triggerUpgradePrompt() {
        showUpgradePrompt = true
    }

    var apiKeySet: Bool { !Constants.API.key.isEmpty }
    var plan: SubscriptionPlan { tokenTracker.plan }
}
