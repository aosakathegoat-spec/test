import AppIntents
import Foundation

// MARK: - Intent

struct AskAriaIntent: AppIntent {
    static var title: LocalizedStringResource = "Ask Aria"
    static var description = IntentDescription(
        "Ask Aria anything — summarize emails, send messages, open apps, and more."
    )
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Request", description: "What would you like Aria to do?")
    var request: String

    static var parameterSummary: some ParameterSummary {
        Summary("Ask Aria to \(\.$request)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        UserDefaults.standard.set(request, forKey: Constants.UserDefaultsKeys.pendingSiriRequest)
        NotificationCenter.default.post(name: .siriRequestReceived, object: request)
        return .result(dialog: "On it!")
    }
}

// MARK: - Shortcuts provider (registers "Hey Siri, ask Aria to…" without any user setup)

struct AriaShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .blue

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AskAriaIntent(),
            phrases: [
                "Ask \(.applicationName) to \(\.$request)",
                "Ask \(.applicationName) \(\.$request)",
                "Tell \(.applicationName) to \(\.$request)"
            ],
            shortTitle: "Ask Aria",
            systemImageName: "sparkles"
        )
    }
}

// MARK: - Notification name

extension Notification.Name {
    static let siriRequestReceived = Notification.Name("com.aria.assistant.siriRequest")
}
