import Foundation
import UserNotifications
import Combine

@MainActor
class MorningBriefingService: ObservableObject {
    static let shared = MorningBriefingService()

    @Published var todayBriefing: String?
    @Published var isGenerating = false
    @Published var lastGenerated: Date?

    private init() {}

    // MARK: - Generate Briefing
    func generateBriefing(emails: [EmailMessage]) async throws -> String {
        isGenerating = true
        defer { isGenerating = false }

        let dateStr = DateFormatter.localizedString(from: Date(), dateStyle: .full, timeStyle: .none)
        let emailSummary = buildEmailSummary(emails)

        let briefingPrompt = """
        Generate a concise, friendly morning briefing for \(dateStr). Structure it as:

        1. **Good morning!** A brief warm greeting (1 sentence)
        2. **Today's overview** - date, day of week (1 sentence)
        3. **Email highlights** - summarize these recent emails:
        \(emailSummary)
        4. **Quick tip or motivation** - a brief, useful insight for the day (1 sentence)

        Keep the total briefing under 200 words. Use a natural, conversational tone as if a friendly assistant is speaking aloud. Avoid markdown symbols in the output—write it as pure speech.
        """

        let message = Message(role: .user, content: briefingPrompt)
        let systemPrompt = """
        You are Aria, a friendly AI morning briefing assistant. Generate spoken-word briefings that sound natural when read aloud by text-to-speech. Use no markdown, no bullet points, no asterisks. Speak conversationally and concisely.
        """

        let (text, usage) = try await AIService.shared.sendMessage(
            messages: [message],
            systemPrompt: systemPrompt
        )

        await TokenTracker.shared.record(
            input: usage.inputTokens,
            output: usage.outputTokens,
            cached: usage.cachedInputTokens
        )

        todayBriefing = text
        lastGenerated = Date()
        return text
    }

    private func buildEmailSummary(_ emails: [EmailMessage]) -> String {
        guard !emails.isEmpty else { return "No new emails." }
        let recent = emails.prefix(5)
        return recent.enumerated().map { i, email in
            "- From \(email.from.displayName): \"\(email.subject)\" — \(email.snippet.prefix(80))"
        }.joined(separator: "\n")
    }

    // MARK: - Scheduling
    func scheduleDailyBriefing(hour: Int, minute: Int) {
        let center = UNUserNotificationCenter.current()

        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }

            center.removePendingNotificationRequests(withIdentifiers: ["morning_briefing"])

            let content = UNMutableNotificationContent()
            content.title = "Good morning! ☀️"
            content.body  = "Your Aria morning briefing is ready."
            content.sound = .default
            content.categoryIdentifier = "morning_briefing"

            var components = DateComponents()
            components.hour   = hour
            components.minute = minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(
                identifier: "morning_briefing",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }

        UserDefaults.standard.set(true,   forKey: Constants.UserDefaultsKeys.morningBriefing)
        UserDefaults.standard.set(hour,   forKey: Constants.UserDefaultsKeys.briefingHour)
        UserDefaults.standard.set(minute, forKey: Constants.UserDefaultsKeys.briefingMinute)
    }

    func cancelDailyBriefing() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["morning_briefing"])
        UserDefaults.standard.set(false, forKey: Constants.UserDefaultsKeys.morningBriefing)
    }

    var scheduledHour: Int   { UserDefaults.standard.integer(forKey: Constants.UserDefaultsKeys.briefingHour) }
    var scheduledMinute: Int { UserDefaults.standard.integer(forKey: Constants.UserDefaultsKeys.briefingMinute) }
    var isScheduled: Bool    { UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.morningBriefing) }
}
