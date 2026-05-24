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

        // Fetch remote messages and subscribe to realtime if backed by Supabase
        if let sbID = group.supabaseID {
            Task { await loadRemoteMessages(groupID: sbID) }
            subscribeRealtime(groupID: group.id.uuidString, supabaseID: group.supabaseID)
        }
    }

    deinit {
        // SupabaseRealtimeManager is @unchecked Sendable with its own lock — safe to call from deinit.
        guard let sbID = group.supabaseID else { return }
        SupabaseRealtimeManager.shared.unsubscribe(groupID: sbID)
    }

    private func loadWelcomeMessage() {
        let intro = group.memberNames.isEmpty
            ? "Hey! I'm Aria, your group AI assistant. What can I help you all with?"
            : "Hey \(group.memberNames.first ?? "everyone")! I'm Aria. I'm here to help the whole group — \(group.memberSummary). What do you need?"
        messages = [Message(role: .assistant, content: intro)]
        persist()
    }

    // MARK: - Supabase integration

    private func loadRemoteMessages(groupID: String) async {
        guard let sbMessages = try? await SupabaseSocialService.shared.fetchMessages(groupID: groupID),
              !sbMessages.isEmpty
        else { return }

        let converted = sbMessages.map { sb in
            Message(
                id: UUID(uuidString: sb.id) ?? UUID(),
                role: MessageRole(rawValue: sb.role) ?? .assistant,
                content: sb.content
            )
        }
        // Use remote as the source of truth
        messages = converted
        persist()
    }

    private func subscribeRealtime(groupID: String, supabaseID: String?) {
        guard let sbID = supabaseID else { return }
        SupabaseRealtimeManager.shared.subscribe(groupID: sbID) { [weak self] sbMsg in
            guard let self else { return }
            // Ignore messages we just sent (already in local messages array)
            let msgID = UUID(uuidString: sbMsg.id) ?? UUID()
            guard !self.messages.contains(where: { $0.id == msgID }) else { return }
            // Only display user messages from other members (Aria's response is handled locally)
            guard sbMsg.role == "user" else { return }
            let msg = Message(id: msgID, role: .user, content: sbMsg.content)
            self.messages.append(msg)
            self.scrollToBottom = true
        }
    }

    // MARK: - System prompt

    private var systemPrompt: String {
        let members = group.memberNames.isEmpty ? "just you" : group.memberNames.joined(separator: ", ")
        return """
        You are Aria, an AI assistant in the group chat "\(group.name)". \
        Members: \(members). Respond naturally to whoever is speaking. \
        You can help with any task — drafting messages, answering questions, \
        planning, summarizing, and more. Keep responses concise and group-friendly.
        """
    }

    // MARK: - Send

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

        // Persist user message to Supabase
        if let sbID = group.supabaseID {
            Task { try? await SupabaseSocialService.shared.sendMessage(groupID: sbID, role: "user", content: text) }
        }

        let assistantID = UUID()
        streamingMessageID = assistantID
        messages.append(Message(id: assistantID, role: .assistant, content: "", isStreaming: true))
        isStreaming = true
        error = nil

        let history = messages.filter { !$0.isStreaming && $0.id != assistantID }
        let windowed = Array(history.suffix(Constants.Chat.memoryWindow))

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            var fullText = ""
            do {
                let stream = await AIService.shared.streamMessage(
                    messages: windowed,
                    systemPrompt: systemPrompt,
                    plan: appState.plan
                )
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

            // Persist Aria's response to Supabase
            if !fullText.isEmpty, let sbID = group.supabaseID {
                Task { try? await SupabaseSocialService.shared.sendMessage(groupID: sbID, role: "assistant", content: fullText) }
            }
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
