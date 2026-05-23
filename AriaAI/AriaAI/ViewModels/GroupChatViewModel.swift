import SwiftUI

@MainActor
class GroupChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var inputText = ""
    @Published var isStreaming = false
    @Published var error: String?
    @Published var scrollToBottom = false

    private(set) var group: GroupConversation
    private let appState = AppState.shared
    private var streamingMessageID: UUID?
    private var activeStreamTask: Task<Void, Never>?

    init(group: GroupConversation) {
        self.group = group
        self.messages = group.messages
        if messages.isEmpty { loadWelcomeMessage() }
    }

    private func loadWelcomeMessage() {
        let intro = group.memberNames.isEmpty
            ? "Hey! I'm Aria, your group AI assistant. What can I help you all with?"
            : "Hey \(group.memberNames.first ?? "everyone")! I'm Aria. I'm here to help the whole group — \(group.memberSummary). What do you need?"
        messages = [Message(role: .assistant, content: intro)]
        persist()
    }

    private var systemPrompt: String {
        let members = group.memberNames.isEmpty ? "just you" : group.memberNames.joined(separator: ", ")
        return """
        You are Aria, an AI assistant in the group chat "\(group.name)". \
        Members: \(members). Respond naturally to whoever is speaking. \
        You can help with any task — drafting messages, answering questions, \
        planning, summarizing, and more. Keep responses concise and group-friendly.
        """
    }

    func sendMessage() async {
        let text = inputText.trimmed
        guard !text.isEmpty, !isStreaming else { return }
        guard appState.apiKeySet else {
            error = AIError.noAPIKey.errorDescription
            return
        }
        guard appState.tokenTracker.canSendRequest() else {
            appState.triggerUpgradePrompt()
            return
        }

        inputText = ""
        let userMsg = Message(role: .user, content: text)
        messages.append(userMsg)
        scrollToBottom = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        let assistantID = UUID()
        streamingMessageID = assistantID
        messages.append(Message(id: assistantID, role: .assistant, content: "", isStreaming: true))
        isStreaming = true
        error = nil

        let history = messages.filter { !$0.isStreaming && $0.id != assistantID }
        let windowed = Array(history.suffix(Constants.Chat.memoryWindow))

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let stream = await AIService.shared.streamMessage(
                    messages: windowed,
                    systemPrompt: systemPrompt,
                    plan: appState.plan
                )
                var fullText = ""
                for try await event in stream {
                    switch event {
                    case .text(let chunk):
                        fullText += chunk
                        if let idx = messages.firstIndex(where: { $0.id == assistantID }) {
                            messages[idx].content = fullText
                        }
                        scrollToBottom = true
                    case .usage(let input, let output, let cached):
                        appState.tokenTracker.record(input: input, output: output, cached: cached)
                        if let idx = messages.firstIndex(where: { $0.id == assistantID }) {
                            messages[idx].isStreaming = false
                        }
                    default: break
                    }
                }
            } catch {
                if !(error is CancellationError) {
                    self.error = error.localizedDescription
                    messages.removeAll { $0.id == assistantID }
                }
            }
            guard !Task.isCancelled else { return }
            if let idx = messages.firstIndex(where: { $0.id == assistantID }) {
                messages[idx].isStreaming = false
            }
            isStreaming = false
            streamingMessageID = nil
            activeStreamTask = nil
            persist()
        }
        activeStreamTask = task
        await task.value
    }

    func cancelStreaming() {
        activeStreamTask?.cancel()
        activeStreamTask = nil
        if let id = streamingMessageID,
           let idx = messages.firstIndex(where: { $0.id == id }) {
            messages[idx].content.isEmpty ? messages.remove(at: idx) : (messages[idx].isStreaming = false)
        }
        isStreaming = false
        streamingMessageID = nil
    }

    func clearError() { error = nil }

    private func persist() {
        group.messages = messages
        FriendsService.shared.saveGroup(group)
    }
}
