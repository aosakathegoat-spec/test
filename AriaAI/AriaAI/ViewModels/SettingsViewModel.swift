import SwiftUI
import Combine

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var apiKeyInput = ""
    @Published var apiKeySaved = false
    @Published var showAPIKey = false
    private var savedTask: Task<Void, Never>?
    @Published var selectedVoiceID = ""
    @Published var morningBriefingEnabled = false
    @Published var briefingHour = 7
    @Published var briefingMinute = 0
    @Published var userName = ""
    @Published var friendsUsername = ""

    let appState       = AppState.shared
    let tokenTracker   = TokenTracker.shared
    let voiceService   = VoiceService.shared
    let emailService   = EmailService.shared
    let purchaseService = PurchaseService.shared

    var usage: TokenUsage { tokenTracker.usage }
    var plan:  SubscriptionPlan { tokenTracker.plan }

    private var cancellables = Set<AnyCancellable>()

    init() {
        loadSettings()
        MorningBriefingService.shared.$isScheduled
            .receive(on: RunLoop.main)
            .assign(to: \.morningBriefingEnabled, on: self)
            .store(in: &cancellables)
    }

    func loadSettings() {
        apiKeyInput = AuthService.shared.apiKey  // reads from Keychain
        selectedVoiceID = voiceService.selectedVoiceID
        morningBriefingEnabled = UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.morningBriefing)
        briefingHour = UserDefaults.standard.object(forKey: Constants.UserDefaultsKeys.briefingHour) != nil
            ? UserDefaults.standard.integer(forKey: Constants.UserDefaultsKeys.briefingHour)
            : 7
        briefingMinute = UserDefaults.standard.integer(forKey: Constants.UserDefaultsKeys.briefingMinute)
        userName = appState.userName
        friendsUsername = FriendsService.shared.myUsername
    }

    func saveAPIKey() {
        AuthService.shared.apiKey = apiKeyInput.trimmed  // saves to Keychain
        apiKeySaved = true
        savedTask?.cancel()
        savedTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.apiKeySaved = false
        }
    }

    func clearAPIKey() {
        apiKeyInput = ""
        AuthService.shared.apiKey = ""
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
        let name = userName.trimmed
        guard !name.isEmpty else { return }
        appState.userName = name
        UserDefaults.standard.set(name, forKey: Constants.UserDefaultsKeys.userName)
    }

    func saveFriendsUsername() {
        FriendsService.shared.updateUsername(friendsUsername)
        friendsUsername = FriendsService.shared.myUsername
    }

    func restorePurchases() async {
        do {
            try await purchaseService.restorePurchases()
        } catch {
            appState.showError(error.localizedDescription)
        }
    }

}
