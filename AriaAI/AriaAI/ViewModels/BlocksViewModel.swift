import SwiftUI

@MainActor
class BlocksViewModel: ObservableObject {
    @Published var automations: [Automation] = []
    @Published var isRunning = false
    @Published var runningID: UUID?
    @Published var runLog: [BlockRunLog] = []
    @Published var currentBlockIndex: Int = -1
    @Published var runError: String?
    @Published var runComplete = false

    private let appState = AppState.shared
    private var runTask: Task<Void, Never>?
    private let storageKey = "automations_v1"

    init() { load() }

    func saveAutomation(_ automation: Automation) {
        automations.removeAll { $0.id == automation.id }
        automations.insert(automation, at: 0)
        persist()
    }

    func deleteAutomation(_ automation: Automation) {
        automations.removeAll { $0.id == automation.id }
        persist()
    }

    func cancelRun() {
        runTask?.cancel()
        runTask = nil
    }

    func run(automation: Automation) {
        guard !isRunning else { return }
        isRunning = true
        runningID = automation.id
        runLog = []
        currentBlockIndex = -1
        runError = nil
        runComplete = false

        runTask = Task { [weak self] in
            guard let self else { return }
            defer {
                self.isRunning = false
                self.runningID = nil
                self.currentBlockIndex = -1
                self.runTask = nil
            }
            do {
                try await self.execute(automation)
                if let idx = self.automations.firstIndex(where: { $0.id == automation.id }) {
                    self.automations[idx].lastRun = Date()
                    self.persist()
                }
                self.runComplete = true
            } catch is CancellationError {
                self.appendLog(blockIndex: self.currentBlockIndex, message: "Cancelled")
            } catch {
                self.runError = error.localizedDescription
                self.appendLog(blockIndex: self.currentBlockIndex, message: error.localizedDescription, isError: true)
            }
        }
    }

    private func execute(_ automation: Automation) async throws {
        var context: [String: String] = [:]

        for (i, block) in automation.blocks.enumerated() {
            try Task.checkCancellation()
            currentBlockIndex = i

            switch block.type {
            case .ai:
                let prompt = interpolate(block.aiPrompt, context: context)
                guard !prompt.isEmpty else {
                    appendLog(blockIndex: i, message: "Skipped: empty prompt")
                    continue
                }
                appendLog(blockIndex: i, message: "Asking AI…")
                let (response, usage) = try await AIService.shared.sendMessage(
                    messages: [Message(role: .user, content: prompt)]
                )
                appState.tokenTracker.record(
                    input: usage.inputTokens,
                    output: usage.outputTokens,
                    cached: usage.cachedInputTokens
                )
                context["ai_output"] = response
                context["previous_output"] = response
                let preview = String(response.prefix(100))
                appendLog(blockIndex: i, message: "AI: \(preview)\(response.count > 100 ? "…" : "")")

            case .readInbox:
                guard appState.emailService.isAuthenticated else {
                    throw EmailError.notAuthenticated
                }
                appendLog(blockIndex: i, message: "Reading inbox…")
                let emails = try await appState.emailService.fetchInbox(maxResults: block.inboxMaxResults)
                let summary = emails.map { "\($0.from.displayName): \($0.subject)" }.joined(separator: "\n")
                context["inbox_summary"] = summary
                context["previous_output"] = summary
                appendLog(blockIndex: i, message: "Read \(emails.count) email\(emails.count == 1 ? "" : "s")")

            case .sendEmail:
                guard appState.emailService.isAuthenticated else {
                    throw EmailError.notAuthenticated
                }
                let to      = interpolate(block.emailTo, context: context)
                let subject = interpolate(block.emailSubject, context: context)
                let body    = interpolate(block.emailBody, context: context)
                let draft   = DraftEmail(to: to, subject: subject, body: body)
                guard draft.isValid else {
                    appendLog(blockIndex: i, message: "Skipped: missing to, subject, or body")
                    continue
                }
                appendLog(blockIndex: i, message: "Sending to \(to)…")
                try await appState.emailService.sendEmail(draft)
                appendLog(blockIndex: i, message: "Email sent to \(to)")

            case .wait:
                appendLog(blockIndex: i, message: "Waiting \(Int(block.waitSeconds))s…")
                try await Task.sleep(nanoseconds: UInt64(block.waitSeconds * 1_000_000_000))
                appendLog(blockIndex: i, message: "Done waiting")
            }
        }
    }

    private func interpolate(_ text: String, context: [String: String]) -> String {
        context.reduce(text) { result, pair in
            result.replacingOccurrences(of: "{{\(pair.key)}}", with: pair.value)
        }
    }

    private func appendLog(blockIndex: Int, message: String, isError: Bool = false) {
        runLog.append(BlockRunLog(blockIndex: blockIndex, message: message, isError: isError))
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([Automation].self, from: data)
        else { return }
        automations = saved
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(automations) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
