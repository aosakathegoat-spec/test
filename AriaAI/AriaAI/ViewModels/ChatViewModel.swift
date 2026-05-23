import SwiftUI
import UIKit
import PhotosUI

struct PendingSMS: Identifiable {
    let id = UUID()
    let phoneNumber: String
    let contactName: String?
    let message: String
}

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var inputText = ""
    @Published var isStreaming = false
    @Published var error: String?
    @Published var selectedImages: [UIImage] = []
    @Published var isVoiceActive = false
    @Published var conversations: [ChatSession] = []
    @Published var currentSessionID = UUID()
    @Published var scrollToBottom = false
    @Published var pendingSMSConfirmation: PendingSMS?

    private let appState = AppState.shared
    private var streamingMessageID: UUID?
    private var activeStreamTask: Task<Void, Never>?
    private var smsContinuation: CheckedContinuation<Bool, Never>?

    init() {
        loadConversations()
        restoreCurrentSession()
    }

    // MARK: - Sending
    func sendMessage() async {
        let text = inputText.trimmed
        guard !text.isEmpty || !selectedImages.isEmpty else { return }
        guard !isStreaming else { return }

        guard appState.apiKeySet else {
            error = AIError.noAPIKey.errorDescription
            return
        }
        guard appState.tokenTracker.canSendRequest() else {
            appState.triggerUpgradePrompt()
            return
        }
        if !selectedImages.isEmpty && !appState.plan.canAnalyzeImages {
            error = AIError.imageNotSupported.errorDescription
            return
        }

        // Capture and clear input
        let images = selectedImages
        inputText = ""
        selectedImages = []

        // Add user message
        let userMessage = Message(role: .user, content: text, images: images.map { AttachedImage(image: $0) })
        messages.append(userMessage)
        scrollToBottom = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        // Add streaming assistant placeholder
        let assistantID = UUID()
        streamingMessageID = assistantID
        let assistantMessage = Message(id: assistantID, role: .assistant, content: "", isStreaming: true)
        messages.append(assistantMessage)
        isStreaming = true
        error = nil

        let history = messages.filter { !$0.isStreaming && $0.id != assistantID }
        let windowedHistory = Array(history.suffix(Constants.Chat.memoryWindow))

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let stream = await AIService.shared.streamMessage(
                    messages: windowedHistory,
                    plan: appState.plan,
                    tools: Constants.Tools.all
                )

                var fullText = ""
                var collectedToolCalls: [(id: String, name: String, input: [String: Any])] = []
                var stopReason = "end_turn"

                for try await event in stream {
                    switch event {
                    case .text(let chunk):
                        fullText += chunk
                        if let idx = messages.firstIndex(where: { $0.id == assistantID }) {
                            messages[idx].content = fullText
                            messages[idx].isStreaming = true
                        }
                        scrollToBottom = true

                    case .toolCall(let id, let name, let input):
                        collectedToolCalls.append((id: id, name: name, input: input))

                    case .stopReason(let reason):
                        stopReason = reason

                    case .usage(let input, let output, let cached):
                        appState.tokenTracker.record(input: input, output: output, cached: cached)
                        let snapshot = TokenUsageSnapshot(inputTokens: input, outputTokens: output, cachedInputTokens: cached)
                        if let idx = messages.firstIndex(where: { $0.id == assistantID }) {
                            messages[idx].tokensUsed = snapshot
                            if collectedToolCalls.isEmpty { messages[idx].isStreaming = false }
                        }
                    }
                }

                // Tool loop: execute tool calls and continue conversation
                if !collectedToolCalls.isEmpty && stopReason == "tool_use" {
                    try await runToolLoop(
                        windowedHistory: windowedHistory,
                        initialText: fullText,
                        initialToolCalls: collectedToolCalls,
                        assistantID: assistantID
                    )
                    fullText = messages.first(where: { $0.id == assistantID })?.content ?? fullText
                }

                if isVoiceActive && !fullText.isEmpty {
                    appState.voiceService.speak(fullText)
                }
            } catch {
                if !(error is CancellationError) {
                    self.error = error.localizedDescription
                    if let idx = messages.firstIndex(where: { $0.id == assistantID }) {
                        messages.remove(at: idx)
                    }
                }
            }
            guard !Task.isCancelled else { return }
            isStreaming = false
            streamingMessageID = nil
            activeStreamTask = nil
            saveCurrentSession()
            generateTitleIfNeeded()
        }
        activeStreamTask = task
        await task.value
    }

    func sendVoiceMessage(_ text: String) async {
        guard !text.isEmpty else { return }
        inputText = text
        await sendMessage()
    }

    // MARK: - Voice mode
    func toggleVoiceMode() {
        isVoiceActive.toggle()
        if !isVoiceActive {
            appState.voiceService.stop()
            if appState.voiceService.isListening {
                appState.voiceService.stopListening()
            }
        }
    }

    func startVoiceInput() async {
        guard appState.plan.canUseVoice else {
            appState.triggerUpgradePrompt()
            return
        }
        await appState.voiceService.startListening()
        if let err = appState.voiceService.speechError {
            error = err
            appState.voiceService.speechError = nil
        }
    }

    func stopVoiceAndSend() async {
        appState.voiceService.stopListening()
        let text = appState.voiceService.recognizedText
        appState.voiceService.recognizedText = ""
        await sendVoiceMessage(text)
    }

    // MARK: - Images
    func addImage(_ image: UIImage) {
        guard appState.plan.canAnalyzeImages else {
            error = AIError.imageNotSupported.errorDescription
            return
        }
        selectedImages.append(image)
    }

    func removeImage(at index: Int) {
        guard index < selectedImages.count else { return }
        selectedImages.remove(at: index)
    }

    // MARK: - Sessions
    func newConversation() {
        if isStreaming { cancelStreaming() }
        saveCurrentSession()
        messages = []
        currentSessionID = UUID()
        UserDefaults.standard.removeObject(forKey: Constants.UserDefaultsKeys.currentSession)
        loadWelcomeMessage()
    }

    private func loadWelcomeMessage() {
        let name = AppState.shared.userName.trimmingCharacters(in: .whitespaces)
        let intro = "I'm Aria, your AI assistant. I can help you draft and send emails, answer questions, analyze images, plan your day, and generate your morning briefing. What can I do for you today?"
        let greeting = Message(
            role: .assistant,
            content: name.isEmpty ? "Hi! \(intro)" : "Hi \(name)! \(intro)"
        )
        messages = [greeting]
    }

    private func restoreCurrentSession() {
        if let idStr = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.currentSession),
           let uuid = UUID(uuidString: idStr),
           let session = conversations.first(where: { $0.id == uuid }) {
            messages = session.messages
            currentSessionID = session.id
        } else {
            loadWelcomeMessage()
        }
    }

    private func saveCurrentSession() {
        guard messages.count > 1 else { return }
        let existingAITitle = conversations.first(where: { $0.id == currentSessionID })?.aiTitle
        let session = ChatSession(
            id: currentSessionID,
            title: sessionTitle,
            aiTitle: existingAITitle,
            messages: messages,
            date: Date()
        )
        conversations.removeAll { $0.id == currentSessionID }
        conversations.insert(session, at: 0)
        conversations = Array(conversations.prefix(20))
        storeSessions()
        UserDefaults.standard.set(currentSessionID.uuidString, forKey: Constants.UserDefaultsKeys.currentSession)
    }

    private func generateTitleIfNeeded() {
        let userMsgs = messages.filter { $0.isUser }
        let aiMsgs   = messages.filter { $0.isAssistant && !$0.isStreaming }
        guard userMsgs.count == 1, aiMsgs.count == 1 else { return }
        guard conversations.first(where: { $0.id == currentSessionID })?.aiTitle == nil else { return }

        let userText = userMsgs[0].content
        let aiText   = aiMsgs[0].content
        let sessionID = currentSessionID

        Task {
            let prompt = "Write a 3-5 word title for this conversation. Return only the title, no quotes or punctuation.\n\nUser: \(userText.prefix(200))\nAssistant: \(aiText.prefix(200))"
            guard let (raw, _) = try? await AIService.shared.sendMessage(
                messages: [Message(role: .user, content: prompt)]
            ) else { return }
            let title = raw
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            guard !title.isEmpty else { return }
            await MainActor.run { [weak self] in
                guard let self else { return }
                if let idx = self.conversations.firstIndex(where: { $0.id == sessionID }) {
                    self.conversations[idx].aiTitle = title
                    self.storeSessions()
                }
            }
        }
    }

    private func loadConversations() {
        guard let data = UserDefaults.standard.data(forKey: Constants.UserDefaultsKeys.chatSessions),
              let sessions = try? JSONDecoder().decode([ChatSession].self, from: data)
        else { return }
        conversations = sessions
    }

    private func storeSessions() {
        guard let data = try? JSONEncoder().encode(conversations) else { return }
        UserDefaults.standard.set(data, forKey: Constants.UserDefaultsKeys.chatSessions)
    }

    func loadSession(_ session: ChatSession) {
        if isStreaming { cancelStreaming() }
        saveCurrentSession()
        messages = session.messages
        currentSessionID = session.id
        UserDefaults.standard.set(session.id.uuidString, forKey: Constants.UserDefaultsKeys.currentSession)
    }

    func deleteSession(_ session: ChatSession) {
        conversations.removeAll { $0.id == session.id }
        storeSessions()
        if session.id == currentSessionID {
            if isStreaming { cancelStreaming() }
            messages = []
            currentSessionID = UUID()
            UserDefaults.standard.removeObject(forKey: Constants.UserDefaultsKeys.currentSession)
            loadWelcomeMessage()
        }
    }

    var sessionTitle: String {
        guard let first = messages.first(where: { $0.isUser }) else { return "New conversation" }
        let text = first.content.components(separatedBy: .newlines).joined(separator: " ").trimmed
        return text.count > 40 ? String(text.prefix(40)) + "…" : text
    }

    // MARK: - SMS confirmation

    func confirmSMSSend() async {
        guard let pending = pendingSMSConfirmation else { return }
        // Keep sheet visible until composer dismisses
        let sent = await SMSService.shared.presentSMSComposer(to: pending.phoneNumber, body: pending.message)
        pendingSMSConfirmation = nil
        smsContinuation?.resume(returning: sent)
        smsContinuation = nil
    }

    func cancelSMSSend() {
        pendingSMSConfirmation = nil
        smsContinuation?.resume(returning: false)
        smsContinuation = nil
    }

    // MARK: - Tool loop (private)

    private func runToolLoop(
        windowedHistory: [Message],
        initialText: String,
        initialToolCalls: [(id: String, name: String, input: [String: Any])],
        assistantID: UUID
    ) async throws {
        defer {
            if let idx = messages.firstIndex(where: { $0.id == assistantID }) {
                messages[idx].isStreaming = false
            }
        }

        var rawMessages = buildAPIMessages(from: windowedHistory)
        var currentText = initialText
        var pendingCalls = initialToolCalls

        for _ in 0..<4 {
            // Mark message as still processing
            if let idx = messages.firstIndex(where: { $0.id == assistantID }) {
                messages[idx].isStreaming = true
            }

            // Build assistant message (text + tool_use blocks)
            var assistantBlocks: [[String: Any]] = []
            if !currentText.isEmpty {
                assistantBlocks.append(["type": "text", "text": currentText])
            }
            for tc in pendingCalls {
                assistantBlocks.append(["type": "tool_use", "id": tc.id, "name": tc.name, "input": tc.input])
            }
            rawMessages.append(["role": "assistant", "content": assistantBlocks])

            // Execute tools
            var toolResultContent: [[String: Any]] = []
            for tc in pendingCalls {
                let result = await executeToolCall(name: tc.name, input: tc.input)
                toolResultContent.append(["type": "tool_result", "tool_use_id": tc.id, "content": result])
            }
            rawMessages.append(["role": "user", "content": toolResultContent])

            // Non-streaming follow-up
            let (nextText, nextCalls, nextUsage) = try await AIService.shared.sendRawWithTools(
                rawMessages: rawMessages,
                tools: Constants.Tools.all
            )
            appState.tokenTracker.record(
                input: nextUsage.inputTokens,
                output: nextUsage.outputTokens,
                cached: nextUsage.cachedInputTokens
            )

            if !nextText.isEmpty {
                if let idx = messages.firstIndex(where: { $0.id == assistantID }) {
                    let existing = messages[idx].content
                    messages[idx].content = existing.isEmpty ? nextText : existing + "\n\n" + nextText
                }
                scrollToBottom = true
            }

            if nextCalls.isEmpty {
                if let idx = messages.firstIndex(where: { $0.id == assistantID }) {
                    messages[idx].isStreaming = false
                }
                break
            }
            currentText = nextText
            pendingCalls = nextCalls
        }
    }

    private func executeToolCall(name: String, input: [String: Any]) async -> String {
        switch name {
        case "get_contacts":
            let query = (input["search"] as? String) ?? ""
            guard !query.isEmpty else { return "Error: search query is required" }
            do {
                let contacts = try await SMSService.shared.searchContacts(query: query)
                guard !contacts.isEmpty else { return "No contacts found matching '\(query)'" }
                return contacts.prefix(8).map { c in
                    let phones = c.phoneNumbers.prefix(2).joined(separator: " / ")
                    return "\(c.name): \(phones)"
                }.joined(separator: "\n")
            } catch {
                return "Error: \(error.localizedDescription)"
            }

        case "send_sms":
            let phoneNumber = (input["phone_number"] as? String) ?? ""
            let contactName = input["contact_name"] as? String
            let message     = (input["message"] as? String) ?? ""
            guard !phoneNumber.isEmpty, !message.isEmpty else {
                return "Error: phone_number and message are required"
            }
            let confirmed = await waitForSMSConfirmation(
                PendingSMS(phoneNumber: phoneNumber, contactName: contactName, message: message)
            )
            if confirmed {
                return "SMS opened in composer for \(contactName ?? phoneNumber). User can review and send."
            } else {
                return "User declined to send the SMS."
            }

        case "get_app_list":
            let category = input["category"] as? String
            let apps = AppLauncherService.shared.getInstalledApps(category: category)
            guard !apps.isEmpty else {
                return "No apps found\(category != nil ? " in category '\(category!)'" : "")."
            }
            let lines = apps.map { "id: \($0.id) | name: \($0.name) | category: \($0.category)" }
            return "Installed apps (\(apps.count)):\n" + lines.joined(separator: "\n")

        case "open_app":
            let appId   = (input["app_id"]   as? String) ?? ""
            let appName = (input["app_name"] as? String) ?? appId
            guard !appId.isEmpty else { return "Error: app_id is required" }
            let success = await AppLauncherService.shared.openApp(id: appId)
            return success
                ? "Opened \(appName) successfully."
                : "Could not open \(appName) — it may not be installed or the app id is incorrect."

        default:
            return "Unknown tool: \(name)"
        }
    }

    private func waitForSMSConfirmation(_ sms: PendingSMS) async -> Bool {
        return await withCheckedContinuation { continuation in
            self.smsContinuation = continuation
            self.pendingSMSConfirmation = sms
        }
    }

    private func buildAPIMessages(from messages: [Message]) -> [[String: Any]] {
        messages.compactMap { msg -> [String: Any]? in
            guard msg.role != .system else { return nil }
            var contentBlocks: [[String: Any]] = []
            if msg.isUser && msg.hasImages {
                for img in msg.images where !img.base64Data.isEmpty {
                    contentBlocks.append([
                        "type": "image",
                        "source": ["type": "base64", "media_type": img.mediaType, "data": img.base64Data]
                    ])
                }
            }
            if !msg.content.isEmpty { contentBlocks.append(["type": "text", "text": msg.content]) }
            guard !contentBlocks.isEmpty else { return nil }
            return ["role": msg.role.rawValue, "content": contentBlocks]
        }
    }

    func cancelStreaming() {
        activeStreamTask?.cancel()
        activeStreamTask = nil
        cancelSMSSend()
        if let id = streamingMessageID,
           let idx = messages.firstIndex(where: { $0.id == id }) {
            if messages[idx].content.isEmpty {
                messages.remove(at: idx)
            } else {
                messages[idx].isStreaming = false
            }
        }
        isStreaming = false
        streamingMessageID = nil
    }

    func clearError() { error = nil }
}

struct ChatSession: Identifiable, Codable {
    let id: UUID
    var title: String
    var aiTitle: String?
    var messages: [Message]
    var date: Date

    var displayTitle: String { aiTitle ?? title }
}
