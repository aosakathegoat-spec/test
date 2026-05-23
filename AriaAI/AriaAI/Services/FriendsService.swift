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
    }

    static func generateUsername() -> String {
        let letters = "abcdefghijklmnopqrstuvwxyz"
        let digits  = "0123456789"
        let l = (0..<3).compactMap { _ in letters.randomElement() }.map(String.init).joined()
        let d = (0..<4).compactMap { _ in digits.randomElement() }.map(String.init).joined()
        return "\(l)-\(d)"
    }

    // MARK: - Friends

    func addFriend(username: String, displayName: String = "") {
        let trimmed = username.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != myUsername else { return }
        guard !friends.contains(where: { $0.username == trimmed }) else { return }
        friends.append(Friend(username: trimmed, displayName: displayName))
        saveFriends()
    }

    func removeFriend(_ friend: Friend) {
        friends.removeAll { $0.id == friend.id }
        saveFriends()
    }

    // MARK: - Groups

    func createGroup(name: String, memberNames: [String]) -> GroupConversation {
        let group = GroupConversation(name: name, memberNames: memberNames)
        groups.insert(group, at: 0)
        saveGroups()
        return group
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
