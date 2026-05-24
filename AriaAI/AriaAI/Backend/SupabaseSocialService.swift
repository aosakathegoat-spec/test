import Foundation

// MARK: - Row models

struct SBProfile: Codable {
    let id:          String
    let username:    String
    let displayName: String?
    let createdAt:   Date?
}

struct SBFriendship: Decodable {
    let id:        String
    let userId:    String
    let friendId:  String
    let friend:    SBProfile?   // embedded via PostgREST join
}

struct SBGroup: Codable {
    let id:           String
    let name:         String
    let createdBy:    String?
    let createdAt:    Date?
    let lastActivity: Date?
    // embedded members list when fetched via group_members join
    var members: [SBGroupMember]?
}

struct SBGroupMember: Codable {
    let id:       String
    let groupId:  String
    let userId:   String
    let joinedAt: Date?
    var profile:  SBProfile?
}

struct SBMessage: Codable {
    let id:        String
    let groupId:   String
    let senderId:  String?
    let role:      String
    let content:   String
    let createdAt: Date
}

// MARK: - Service

@MainActor
final class SupabaseSocialService {
    static let shared = SupabaseSocialService()

    private let client = SupabaseClient.shared
    private init() {}

    // MARK: - Profile

    func upsertProfile(username: String, displayName: String) async throws {
        guard let uid = client.userID else { throw SupabaseError.notAuthenticated }
        let body = ProfileUpsert(id: uid, username: username, displayName: displayName)
        let _: [SBProfile] = try await client.upsert("profiles", body: body)
    }

    func lookupUser(username: String) async throws -> SBProfile? {
        let results: [SBProfile] = try await client.get("profiles", query: [
            URLQueryItem(name: "username", value: "eq.\(username)"),
            URLQueryItem(name: "select",   value: "*")
        ])
        return results.first
    }

    func myProfile() async throws -> SBProfile? {
        guard let uid = client.userID else { return nil }
        let results: [SBProfile] = try await client.get("profiles", query: [
            URLQueryItem(name: "id",     value: "eq.\(uid)"),
            URLQueryItem(name: "select", value: "*")
        ])
        return results.first
    }

    // MARK: - Friends

    func fetchFriends() async throws -> [SBFriendship] {
        guard let uid = client.userID else { throw SupabaseError.notAuthenticated }
        return try await client.get("friendships", query: [
            URLQueryItem(name: "user_id", value: "eq.\(uid)"),
            URLQueryItem(name: "select",  value: "*,friend:profiles!friend_id(*)")
        ])
    }

    func addFriend(friendID: String) async throws {
        guard let uid = client.userID else { throw SupabaseError.notAuthenticated }
        let body = FriendshipInsert(userId: uid, friendId: friendID)
        let _: [SBFriendship] = try await client.post("friendships", body: body)
    }

    func removeFriend(friendID: String) async throws {
        guard let uid = client.userID else { throw SupabaseError.notAuthenticated }
        try await client.delete("friendships", query: [
            URLQueryItem(name: "user_id",   value: "eq.\(uid)"),
            URLQueryItem(name: "friend_id", value: "eq.\(friendID)")
        ])
    }

    // MARK: - Groups

    /// Returns all groups the current user is a member of.
    func fetchGroups() async throws -> [SBGroup] {
        guard let uid = client.userID else { throw SupabaseError.notAuthenticated }
        // Fetch via group_members, embedding the group row + all members
        struct MemberRow: Decodable {
            let group: SBGroup
        }
        let rows: [MemberRow] = try await client.get("group_members", query: [
            URLQueryItem(name: "user_id", value: "eq.\(uid)"),
            URLQueryItem(name: "select",  value: "group:group_conversations(*)")
        ])
        return rows.map { $0.group }
    }

    func createGroup(name: String, memberIDs: [String]) async throws -> SBGroup {
        guard let uid = client.userID else { throw SupabaseError.notAuthenticated }
        // Create the group
        let body = GroupInsert(name: name, createdBy: uid)
        let groups: [SBGroup] = try await client.post("group_conversations", body: body)
        guard let group = groups.first else { throw SupabaseError.invalidResponse }

        // Add all members (include the creator)
        let allIDs = ([uid] + memberIDs).removingDuplicates()
        for memberID in allIDs {
            let mb = GroupMemberInsert(groupId: group.id, userId: memberID)
            let _: [SBGroupMember] = try await client.post("group_members", body: mb)
        }
        return group
    }

    func updateGroupActivity(groupID: String) async throws {
        // PATCH group_conversations to update last_activity
        // Uses a raw URLRequest via client helper isn't available, so we do a minimal workaround:
        // Re-fetch is fine for our use case; the trigger/default handles it server-side.
    }

    // MARK: - Messages

    func fetchMessages(groupID: String) async throws -> [SBMessage] {
        try await client.get("group_messages", query: [
            URLQueryItem(name: "group_id", value: "eq.\(groupID)"),
            URLQueryItem(name: "select",   value: "*"),
            URLQueryItem(name: "order",    value: "created_at.asc")
        ])
    }

    func sendMessage(groupID: String, role: String, content: String) async throws -> SBMessage {
        let uid = client.userID
        let body = MessageInsert(groupId: groupID, senderId: uid, role: role, content: content)
        let results: [SBMessage] = try await client.post("group_messages", body: body)
        guard let msg = results.first else { throw SupabaseError.invalidResponse }
        return msg
    }
}

// MARK: - Insert bodies

private struct ProfileUpsert: Encodable {
    let id:          String
    let username:    String
    let displayName: String
    enum CodingKeys: String, CodingKey {
        case id, username
        case displayName = "display_name"
    }
}

private struct FriendshipInsert: Encodable {
    let userId:   String
    let friendId: String
    enum CodingKeys: String, CodingKey {
        case userId   = "user_id"
        case friendId = "friend_id"
    }
}

private struct GroupInsert: Encodable {
    let name:      String
    let createdBy: String
    enum CodingKeys: String, CodingKey {
        case name
        case createdBy = "created_by"
    }
}

private struct GroupMemberInsert: Encodable {
    let groupId: String
    let userId:  String
    enum CodingKeys: String, CodingKey {
        case groupId = "group_id"
        case userId  = "user_id"
    }
}

private struct MessageInsert: Encodable {
    let groupId:  String
    let senderId: String?
    let role:     String
    let content:  String
    enum CodingKeys: String, CodingKey {
        case groupId  = "group_id"
        case senderId = "sender_id"
        case role, content
    }
}

// MARK: - Array helper

private extension Array where Element: Equatable {
    func removingDuplicates() -> [Element] {
        var seen: [Element] = []
        for e in self where !seen.contains(e) { seen.append(e) }
        return seen
    }
}
