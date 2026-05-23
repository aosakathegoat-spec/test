import SwiftUI
import Combine

@MainActor
class InboxViewModel: ObservableObject {
    @Published var emails: [EmailMessage] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var searchText = ""
    @Published var selectedEmail: EmailMessage?
    @Published var showCompose = false
    @Published var draftEmail = DraftEmail()
    @Published var isSending = false
    @Published var isGeneratingDraft = false

    private let emailService = EmailService.shared
    private let appState = AppState.shared

    var filteredEmails: [EmailMessage] {
        guard !searchText.isEmpty else { return emails }
        let q = searchText.lowercased().trimmingCharacters(in: .whitespaces)
        return emails.filter {
            $0.subject.lowercased().contains(q) ||
            $0.from.displayName.lowercased().contains(q) ||
            $0.snippet.lowercased().contains(q)
        }
    }

    var unreadCount: Int { emails.filter { !$0.isRead }.count }

    func loadEmails() async {
        guard emailService.isAuthenticated else { return }
        guard appState.plan.canReadEmails else { return }
        guard !isLoading else { return }
        isLoading = true
        error = nil
        do {
            emails = try await emailService.fetchInbox()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func sendEmail() async {
        guard draftEmail.isValid else {
            error = "Please fill in To, Subject, and message body."
            return
        }
        guard !isSending else { return }
        isSending = true
        error = nil
        do {
            try await emailService.sendEmail(draftEmail)
            let gen = UINotificationFeedbackGenerator()
            gen.prepare()
            gen.notificationOccurred(.success)
            draftEmail = DraftEmail()
            showCompose = false
        } catch {
            let gen = UINotificationFeedbackGenerator()
            gen.prepare()
            gen.notificationOccurred(.error)
            self.error = error.localizedDescription
        }
        isSending = false
    }

    func generateAIDraft(replyTo email: EmailMessage? = nil) async {
        guard !isGeneratingDraft else { return }
        guard appState.apiKeySet else {
            error = AIError.noAPIKey.errorDescription
            return
        }
        guard appState.tokenTracker.canSendRequest(estimatedTokens: 300) else {
            appState.triggerUpgradePrompt()
            return
        }

        isGeneratingDraft = true
        defer { isGeneratingDraft = false }

        var prompt: String
        if let email {
            prompt = """
            Draft a professional reply to this email:
            From: \(email.from.displayName) <\(email.from.email)>
            Subject: \(email.subject)
            Body: \(email.body.prefix(500))

            Write only the email body text, no subject line or greeting setup.
            """
            draftEmail.to = email.from.email
            draftEmail.subject = "Re: \(email.subject)"
        } else {
            prompt = "Draft a professional email based on this request: \(draftEmail.subject.isEmpty ? "General email" : draftEmail.subject)"
        }

        do {
            let message = Message(role: .user, content: prompt)
            let (text, usage) = try await AIService.shared.sendMessage(messages: [message])
            appState.tokenTracker.record(input: usage.inputTokens, output: usage.outputTokens, cached: usage.cachedInputTokens)
            draftEmail.body = text
        } catch {
            self.error = error.localizedDescription
        }
    }

    func markAsRead(_ email: EmailMessage) {
        if let idx = emails.firstIndex(where: { $0.id == email.id }) {
            emails[idx].isRead = true
        }
    }

    func authenticateGmail() async {
        do {
            try await emailService.authenticate()
            await loadEmails()
        } catch EmailError.authCancelled {
            return
        } catch {
            self.error = error.localizedDescription
        }
    }
}
