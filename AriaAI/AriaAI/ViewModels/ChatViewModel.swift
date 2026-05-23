import SwiftUI
import UIKit
import PhotosUI

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var inputText = ""
    @Published var isStreaming = false
    @Published var error: String?
    @Published var selectedImages: [UIImage] = []
    @Published var isPickingImages = false
    @Published var showVoiceMode = false
    @Published var isVoiceActive = false
    @Published var conversations: [ChatSession] = []
    @Published var currentSessionID = UUID()
    @Published var scrollToBottom = false

    private let appState = AppState.shared
    private var streamingMessageID: UUID?

    init() {
        loadWelcomeMessage()
        loadConversations()
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
        var userMessage = Message(role: .user, content: text, images: images.map { AttachedImage(image: $0) })
        messages.append(userMessage)
        scrollToBottom = true

        // Add streaming assistant placeholder
        let assistantID = UUID()
        streamingMessageID = assistantID
        var assistantMessage = Message(id: assistantID, role: .assistant, content: "", isStreaming: true)
        messages.append(assistantMessage)
        isStreaming = true
        error = nil

        do {
            // Build context window: exclude the streaming placeholder, then take last N messages
            let history = messages.filter { !$0.isStreaming && $0.id != assistantID }
            let windowedHistory = Array(history.suffix(Constants.Chat.memoryWindow))

            let stream = await AIService.shared.streamMessage(
                messages: windowedHistory,
                images: images,
                plan: appState.plan
            )

            var fullText = ""
            for try await event in stream {
                switch event {
                case .text(let chunk):
                    fullText += chunk
                    if let idx = messages.firstIndex(where: { $0.id == assistantID }) {
                        messages[idx].content = fullText
                        messages[idx].isStreaming = true
                    }
                    scrollToBottom = true

                case .usage(let input, let output, let cached):
                    appState.tokenTracker.record(input: input, output: output, cached: cached)
                    let snapshot = TokenUsageSnapshot(inputTokens: input, outputTokens: output, cachedInputTokens: cached)
                    if let idx = messages.firstIndex(where: { $0.id == assistantID }) {
                        messages[idx].tokensUsed = snapshot
                        messages[idx].isStreaming = false
                    }
                }
            }

            // Speak response in voice mode
            if isVoiceActive && !fullText.isEmpty {
                appState.voiceService.speak(fullText)
            }

        } catch {
            self.error = error.localizedDescription
            if let idx = messages.firstIndex(where: { $0.id == assistantID }) {
                messages.remove(at: idx)
            }
        }

        isStreaming = false
        streamingMessageID = nil
        saveCurrentSession()
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
        saveCurrentSession()
        messages = []
        currentSessionID = UUID()
        loadWelcomeMessage()
    }

    private func loadWelcomeMessage() {
        let name = AppState.shared.userName
        let greeting = Message(
            role: .assistant,
            content: "Hi \(name)! I'm Aria, your AI assistant. I can help you with emails, answer questions, analyze images, and more. What can I do for you today?"
        )
        messages = [greeting]
    }

    private func saveCurrentSession() {
        guard messages.count > 1 else { return }
        let session = ChatSession(
            id: currentSessionID,
            title: sessionTitle,
            messages: messages,
            date: Date()
        )
        conversations.removeAll { $0.id == currentSessionID }
        conversations.insert(session, at: 0)
        conversations = Array(conversations.prefix(20))
        storeSessions()
    }

    private func loadConversations() {
        guard let data = UserDefaults.standard.data(forKey: "chat_sessions"),
              let sessions = try? JSONDecoder().decode([ChatSession].self, from: data)
        else { return }
        conversations = sessions
    }

    private func storeSessions() {
        guard let data = try? JSONEncoder().encode(conversations) else { return }
        UserDefaults.standard.set(data, forKey: "chat_sessions")
    }

    func loadSession(_ session: ChatSession) {
        saveCurrentSession()
        messages = session.messages
        currentSessionID = session.id
    }

    func deleteSession(_ session: ChatSession) {
        conversations.removeAll { $0.id == session.id }
        storeSessions()
    }

    var sessionTitle: String {
        let userMsgs = messages.filter { $0.isUser }
        return userMsgs.first?.content.prefix(40).description ?? "New conversation"
    }

    func clearError() { error = nil }
}

struct ChatSession: Identifiable, Codable {
    let id: UUID
    var title: String
    var messages: [Message]
    var date: Date
}
