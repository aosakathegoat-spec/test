import Foundation

// MARK: - Friend

struct Friend: Identifiable, Codable {
    let id: UUID
    var username: String
    var displayName: String
    let addedAt: Date

    init(id: UUID = UUID(), username: String, displayName: String = "") {
        self.id = id
        self.username = username
        self.displayName = displayName.isEmpty ? username : displayName
        self.addedAt = Date()
    }

    var avatarLetter: String {
        (displayName.first ?? username.first).map(String.init)?.uppercased() ?? "?"
    }
}

// MARK: - Group Conversation

struct GroupConversation: Identifiable, Codable {
    let id: UUID
    var name: String
    var memberNames: [String]
    var messages: [Message]
    let createdAt: Date

    init(id: UUID = UUID(), name: String, memberNames: [String] = []) {
        self.id = id
        self.name = name
        self.memberNames = memberNames
        self.messages = []
        self.createdAt = Date()
    }

    var lastActivity: Date { messages.last?.timestamp ?? createdAt }

    var memberSummary: String {
        let names = memberNames.prefix(3).joined(separator: ", ")
        let overflow = memberNames.count > 3 ? " +\(memberNames.count - 3)" : ""
        return memberNames.isEmpty ? "Just you + Aria" : "\(names)\(overflow) + Aria"
    }
}
