import Foundation

@MainActor
final class FriendsService: ObservableObject {
    static let shared = FriendsService()

    @Published var myUsername: String = ""
    @Published var friends: [Friend] = []
    @Published var groups: [GroupConversation] = []

    private let usernameKey = Constants.UserDefaultsKeys.friendsUsername
    private let friendsKey  = "friends_list_v1"
    private let groupsKey   = "group_conversations_v1"

    private init() {
        loadUsername()
        loadFriends()
        loadGroups()
        // Kick off background sync without blocking init
        Task { await syncFromSupabase() }
    }

    // MARK: - Username

    private func loadUsername() {
        if let saved = UserDefaults.standard.string(forKey: usernameKey), !saved.isEmpty {
            myUsername = saved
        } else {
            myUsername = Self.generateUsername()
            UserDefaults.standard.set(myUsername, forKey: usernameKey)
        }
    }

    func updateUsername(_ new: String) {
        let cleaned = new.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
        guard !cleaned.isEmpty else { return }
        myUsername = cleaned
        UserDefaults.standard.set(myUsername, forKey: usernameKey)
        Task {
            try? await SupabaseSocialService.shared.upsertProfile(
                username: cleaned,
                displayName: AppState.shared.userName
            )
        }
    }

    static func generateUsername() -> String {
        let letters = "abcdefghijklmnopqrstuvwxyz"
        let digits  = "0123456789"
        let l = (0..<3).compactMap { _ in letters.randomElement() }.map(String.init).joined()
        let d = (0..<4).compactMap { _ in digits.randomElement() }.map(String.init).joined()
        return "\(l)-\(d)"
    }

    // MARK: - Friends

    /// Looks up a username on Supabase, then adds locally and remotely.
    func addFriendByUsername(_ username: String, displayName: String = "") async throws {
        let trimmed = username.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != myUsername else { return }
        guard !friends.contains(where: { $0.username == trimmed }) else { return }

        // Optimistic local add
        friends.append(Friend(username: trimmed, displayName: displayName))
        saveFriends()

        // Sync to Supabase if authenticated
        guard SupabaseClient.shared.isAuthenticated else { return }
        if let profile = try? await SupabaseSocialService.shared.lookupUser(username: trimmed) {
            try? await SupabaseSocialService.shared.addFriend(friendID: profile.id)
        }
    }

    func addFriend(username: String, displayName: String = "") {
        let trimmed = username.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != myUsername else { return }
        guard !friends.contains(where: { $0.username == trimmed }) else { return }
        friends.append(Friend(username: trimmed, displayName: displayName))
        saveFriends()
        Task {
            guard SupabaseClient.shared.isAuthenticated else { return }
            if let profile = try? await SupabaseSocialService.shared.lookupUser(username: trimmed) {
                try? await SupabaseSocialService.shared.addFriend(friendID: profile.id)
            }
        }
    }

    func removeFriend(_ friend: Friend) {
        friends.removeAll { $0.id == friend.id }
        saveFriends()
        Task {
            guard SupabaseClient.shared.isAuthenticated else { return }
            if let profile = try? await SupabaseSocialService.shared.lookupUser(username: friend.username) {
                try? await SupabaseSocialService.shared.removeFriend(friendID: profile.id)
            }
        }
    }

    // MARK: - Groups

    func createGroup(name: String, memberNames: [String]) -> GroupConversation {
        let group = GroupConversation(name: name, memberNames: memberNames)
        groups.insert(group, at: 0)
        saveGroups()
        Task { await syncCreateGroup(group, memberNames: memberNames) }
        return group
    }

    private func syncCreateGroup(_ group: GroupConversation, memberNames: [String]) async {
        guard SupabaseClient.shared.isAuthenticated else { return }
        // Resolve usernames to Supabase UUIDs
        var memberIDs: [String] = []
        for username in memberNames {
            if let profile = try? await SupabaseSocialService.shared.lookupUser(username: username) {
                memberIDs.append(profile.id)
            }
        }
        do {
            let sbGroup = try await SupabaseSocialService.shared.createGroup(
                name: group.name, memberIDs: memberIDs
            )
            // Store the Supabase group ID so GroupChatViewModel can use it
            if var updated = groups.first(where: { $0.id == group.id }) {
                updated.supabaseID = sbGroup.id
                saveGroup(updated)
            }
        } catch {
            print("[Supabase] createGroup failed: \(error.localizedDescription)")
        }
    }

    func saveGroup(_ group: GroupConversation) {
        if let idx = groups.firstIndex(where: { $0.id == group.id }) {
            groups[idx] = group
        } else {
            groups.insert(group, at: 0)
        }
        groups.sort { $0.lastActivity > $1.lastActivity }
        saveGroups()
    }

    func deleteGroup(_ group: GroupConversation) {
        groups.removeAll { $0.id == group.id }
        saveGroups()
    }

    // MARK: - Supabase sync

    func syncFromSupabase() async {
        guard SupabaseClient.shared.isAuthenticated else { return }
        await syncFriends()
        await syncGroups()
    }

    private func syncFriends() async {
        guard let friendships = try? await SupabaseSocialService.shared.fetchFriends() else { return }
        let remoteFriends = friendships.compactMap { fs -> Friend? in
            guard let profile = fs.friend else { return nil }
            return Friend(username: profile.username, displayName: profile.displayName ?? profile.username)
        }
        // Merge: keep locals not in remote, add any remote not already local
        var merged = friends
        for remote in remoteFriends {
            if !merged.contains(where: { $0.username == remote.username }) {
                merged.append(remote)
            }
        }
        friends = merged
        saveFriends()
    }

    private func syncGroups() async {
        guard let sbGroups = try? await SupabaseSocialService.shared.fetchGroups() else { return }
        for sbGroup in sbGroups {
            if !groups.contains(where: { $0.supabaseID == sbGroup.id }) {
                let local = GroupConversation(
                    name: sbGroup.name,
                    memberNames: []  // members fetched lazily when group is opened
                )
                var updated = local
                updated.supabaseID = sbGroup.id
                groups.append(updated)
            }
        }
        saveGroups()
    }

    // MARK: - Persistence

    private func saveFriends() {
        if let data = try? JSONEncoder().encode(friends) {
            UserDefaults.standard.set(data, forKey: friendsKey)
        }
    }

    private func loadFriends() {
        guard let data = UserDefaults.standard.data(forKey: friendsKey),
              let saved = try? JSONDecoder().decode([Friend].self, from: data) else { return }
        friends = saved
    }

    private func saveGroups() {
        if let data = try? JSONEncoder().encode(groups) {
            UserDefaults.standard.set(data, forKey: groupsKey)
        }
    }

    private func loadGroups() {
        guard let data = UserDefaults.standard.data(forKey: groupsKey),
              let saved = try? JSONDecoder().decode([GroupConversation].self, from: data) else { return }
        groups = saved
    }
}
