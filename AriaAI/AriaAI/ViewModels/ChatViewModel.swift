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
    private var activeStreamTask: Task<Void, Never>?

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
            isStreaming = false
            streamingMessageID = nil
            activeStreamTask = nil
            saveCurrentSession()
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
        UserDefaults.standard.removeObject(forKey: Constants.UserDefaultsKeys.currentSession)
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
        UserDefaults.standard.set(currentSessionID.uuidString, forKey: Constants.UserDefaultsKeys.currentSession)
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
        saveCurrentSession()
        messages = session.messages
        currentSessionID = session.id
        UserDefaults.standard.set(session.id.uuidString, forKey: Constants.UserDefaultsKeys.currentSession)
    }

    func deleteSession(_ session: ChatSession) {
        conversations.removeAll { $0.id == session.id }
        storeSessions()
    }

    var sessionTitle: String {
        guard let first = messages.first(where: { $0.isUser }) else { return "New conversation" }
        let text = first.content.trimmed
        return text.count > 40 ? String(text.prefix(40)) + "…" : text
    }

    func cancelStreaming() {
        activeStreamTask?.cancel()
        activeStreamTask = nil
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
    var messages: [Message]
    var date: Date
}
