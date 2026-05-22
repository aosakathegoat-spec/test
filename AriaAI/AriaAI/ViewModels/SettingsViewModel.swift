import SwiftUI
import Combine

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var apiKeyInput = ""
    @Published var apiKeySaved = false
    @Published var showAPIKey = false
    @Published var selectedVoiceID = ""
    @Published var morningBriefingEnabled = false
    @Published var briefingHour = 7
    @Published var briefingMinute = 0
    @Published var userName = ""

    let appState       = AppState.shared
    let tokenTracker   = TokenTracker.shared
    let voiceService   = VoiceService.shared
    let emailService   = EmailService.shared
    let purchaseService = PurchaseService.shared

    var usage: TokenUsage { tokenTracker.usage }
    var plan:  SubscriptionPlan { tokenTracker.plan }

    init() {
        loadSettings()
    }

    func loadSettings() {
        apiKeyInput = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.apiKey) ?? ""
        selectedVoiceID = voiceService.selectedVoiceID
        morningBriefingEnabled = UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.morningBriefing)
        briefingHour = UserDefaults.standard.integer(forKey: Constants.UserDefaultsKeys.briefingHour).nonZero ?? 7
        briefingMinute = UserDefaults.standard.integer(forKey: Constants.UserDefaultsKeys.briefingMinute)
        userName = appState.userName
    }

    func saveAPIKey() {
        let key = apiKeyInput.trimmed
        UserDefaults.standard.set(key, forKey: Constants.UserDefaultsKeys.apiKey)
        apiKeySaved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.apiKeySaved = false
        }
    }

    func clearAPIKey() {
        apiKeyInput = ""
        UserDefaults.standard.removeObject(forKey: Constants.UserDefaultsKeys.apiKey)
    }

    func saveVoiceSelection(_ id: String) {
        voiceService.selectVoice(id: id)
        selectedVoiceID = id
    }

    func previewVoice(_ id: String) {
        voiceService.selectVoice(id: id)
        voiceService.speak("Hi, I'm Aria. This is how I sound.")
    }

    func saveMorningBriefingSettings() {
        if morningBriefingEnabled {
            MorningBriefingService.shared.scheduleDailyBriefing(hour: briefingHour, minute: briefingMinute)
        } else {
            MorningBriefingService.shared.cancelDailyBriefing()
        }
    }

    func saveUserName() {
        appState.completeOnboarding(name: userName)
    }

    func restorePurchases() async {
        do {
            try await purchaseService.restorePurchases()
        } catch {
            appState.showError(error.localizedDescription)
        }
    }

    // MARK: - Usage stats
    var totalTokensFormatted: String    { usage.totalTokens.tokenFormatted }
    var inputTokensFormatted: String    { usage.inputTokens.tokenFormatted }
    var outputTokensFormatted: String   { usage.outputTokens.tokenFormatted }
    var cachedTokensFormatted: String   { usage.cachedInputTokens.tokenFormatted }
    var limitFormatted: String          { plan.tokenLimit.tokenFormatted }
    var remainingFormatted: String      { tokenTracker.remainingTokens.tokenFormatted }
    var usagePercent: Double            { tokenTracker.usagePercent }
    var estimatedCost: String           { String(format: "$%.4f", usage.estimatedCost) }

    var briefingTimeFormatted: String {
        let h = briefingHour > 12 ? briefingHour - 12 : (briefingHour == 0 ? 12 : briefingHour)
        let m = String(format: "%02d", briefingMinute)
        let period = briefingHour >= 12 ? "PM" : "AM"
        return "\(h):\(m) \(period)"
    }
}

extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}
