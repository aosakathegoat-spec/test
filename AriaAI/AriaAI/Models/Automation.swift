import SwiftUI

enum BlockType: String, Codable, CaseIterable {
    case ai
    case sendEmail
    case readInbox
    case wait

    var displayName: String {
        switch self {
        case .ai:        return "Ask AI"
        case .sendEmail: return "Send Email"
        case .readInbox: return "Read Inbox"
        case .wait:      return "Wait"
        }
    }

    var icon: String {
        switch self {
        case .ai:        return "sparkles"
        case .sendEmail: return "paperplane.fill"
        case .readInbox: return "tray.full.fill"
        case .wait:      return "clock.fill"
        }
    }

    var colorHex: String {
        switch self {
        case .ai:        return "#9B6DFF"
        case .sendEmail: return "#34D399"
        case .readInbox: return "#FBBF24"
        case .wait:      return "#60A5FA"
        }
    }

    var blockDescription: String {
        switch self {
        case .ai:        return "Send a prompt to Claude and capture the response"
        case .sendEmail: return "Send an email via Gmail"
        case .readInbox: return "Fetch recent emails → {{inbox_summary}}"
        case .wait:      return "Pause execution for N seconds"
        }
    }
}

struct AutomationBlock: Identifiable, Codable {
    var id: UUID = UUID()
    var type: BlockType
    var aiPrompt: String = ""
    var emailTo: String = ""
    var emailSubject: String = ""
    var emailBody: String = ""
    var inboxMaxResults: Int = 5
    var waitSeconds: Double = 5.0

    init(type: BlockType) {
        self.id = UUID()
        self.type = type
    }

    var summary: String {
        switch type {
        case .ai:
            return aiPrompt.isEmpty ? "No prompt set" : String(aiPrompt.prefix(50)) + (aiPrompt.count > 50 ? "…" : "")
        case .sendEmail:
            return emailTo.isEmpty ? "No recipient" : "To: \(emailTo)"
        case .readInbox:
            return "Fetch \(inboxMaxResults) email\(inboxMaxResults == 1 ? "" : "s")"
        case .wait:
            return "\(Int(waitSeconds))s delay"
        }
    }
}

struct Automation: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String = "New Automation"
    var blocks: [AutomationBlock] = []
    var createdAt: Date = Date()
    var lastRun: Date?
}

struct BlockRunLog: Identifiable {
    var id: UUID = UUID()
    var blockIndex: Int
    var message: String
    var isError: Bool = false
    var timestamp: Date = Date()
}
