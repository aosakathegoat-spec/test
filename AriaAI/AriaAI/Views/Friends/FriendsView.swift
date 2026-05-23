import SwiftUI
import UIKit

struct FriendsView: View {
    @StateObject private var service = FriendsService.shared
    @State private var selectedSegment = 0
    @State private var showAddFriend   = false
    @State private var showNewGroup    = false
    @State private var activeGroup: GroupConversation?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                navBar
                segmentPicker
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.bottom, Theme.Spacing.sm)

                if selectedSegment == 0 {
                    friendsList
                        .transition(.opacity)
                } else {
                    groupsList
                        .transition(.opacity)
                }
            }
            .animation(Theme.Animation.snappy, value: selectedSegment)

            fab
        }
        .sheet(isPresented: $showAddFriend) {
            AddFriendSheet()
        }
        .sheet(isPresented: $showNewGroup) {
            NewGroupSheet()
        }
        .fullScreenCover(item: $activeGroup) { group in
            GroupChatView(group: group)
        }
    }

    // MARK: - Nav bar

    private var navBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Friends")
                    .font(Theme.Typography.title(.semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("@\(service.myUsername)")
                    .font(Theme.Typography.caption(.medium))
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            Spacer()
            Button {
                UIPasteboard.general.string = service.myUsername
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Copy my username")
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
    }

    // MARK: - Segment picker

    private var segmentPicker: some View {
        HStack(spacing: 0) {
            segmentButton("Friends", index: 0)
            segmentButton("Groups",  index: 1)
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private func segmentButton(_ title: String, index: Int) -> some View {
        Button {
            withAnimation(Theme.Animation.snappy) { selectedSegment = index }
        } label: {
            Text(title)
                .font(Theme.Typography.subheadline(selectedSegment == index ? .semibold : .regular))
                .foregroundStyle(selectedSegment == index ? Theme.Colors.textPrimary : Theme.Colors.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    Group {
                        if selectedSegment == index {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Theme.Colors.surface)
                        }
                    }
                )
                .padding(3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Friends list

    private var friendsList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if service.friends.isEmpty {
                    emptyFriends.padding(.top, 60)
                } else {
                    ForEach(service.friends) { friend in
                        FriendRow(friend: friend) {
                            service.removeFriend(friend)
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, Theme.Spacing.sm)
            .padding(.bottom, 120)
        }
    }

    private var emptyFriends: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 48))
                .foregroundStyle(Theme.Colors.textTertiary)
            Text("No friends yet")
                .font(Theme.Typography.title3())
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("Share your username @\(service.myUsername)\nand add theirs to connect.")
                .font(Theme.Typography.subheadline())
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Groups list

    private var groupsList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if service.groups.isEmpty {
                    emptyGroups.padding(.top, 60)
                } else {
                    ForEach(service.groups) { group in
                        GroupRow(group: group) {
                            activeGroup = group
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                service.deleteGroup(group)
                            } label: {
                                Label("Delete Group", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, Theme.Spacing.sm)
            .padding(.bottom, 120)
        }
    }

    private var emptyGroups: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(Theme.Colors.textTertiary)
            Text("No group chats")
                .font(Theme.Typography.title3())
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("Create a group to chat with\nyour friends and Aria together.")
                .font(Theme.Typography.subheadline())
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - FAB

    private var fab: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            if selectedSegment == 0 { showAddFriend = true } else { showNewGroup = true }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Theme.Colors.gradientPrimary)
                .clipShape(Circle())
                .shadow(color: Theme.Colors.primary.opacity(0.4), radius: 14, y: 5)
        }
        .padding(.trailing, Theme.Spacing.md)
        .padding(.bottom, 100)
    }
}

// MARK: - Friend Row

struct FriendRow: View {
    let friend: Friend
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            avatarCircle(letter: friend.avatarLetter, gradient: friendGradient(friend.username))

            VStack(alignment: .leading, spacing: 2) {
                Text(friend.displayName)
                    .font(Theme.Typography.subheadline(.semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("@\(friend.username)")
                    .font(Theme.Typography.caption())
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            Spacer()
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius, style: .continuous)
                .fill(Theme.Colors.surface)
        )
        .contextMenu {
            Button(role: .destructive, action: onRemove) {
                Label("Remove Friend", systemImage: "person.fill.xmark")
            }
        }
    }
}

// MARK: - Group Row

struct GroupRow: View {
    let group: GroupConversation
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Theme.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.gradientPrimary)
                        .frame(width: 44, height: 44)
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(group.name)
                        .font(Theme.Typography.subheadline(.semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(1)
                    Text(group.memberSummary)
                        .font(Theme.Typography.caption())
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .lineLimit(1)
                }
                Spacer()

                if let last = group.messages.last(where: { $0.isAssistant }) {
                    Text(last.content.prefix(30) + (last.content.count > 30 ? "…" : ""))
                        .font(Theme.Typography.caption())
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineLimit(1)
                        .frame(maxWidth: 80, alignment: .trailing)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            .padding(Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius, style: .continuous)
                    .fill(Theme.Colors.surface)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Add Friend Sheet

struct AddFriendSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = FriendsService.shared
    @State private var usernameInput = ""
    @State private var displayNameInput = ""
    @State private var added = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                VStack(spacing: Theme.Spacing.xl) {
                    VStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 48, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(colors: [Color(hex: "#4F8EF7"), Color(hex: "#9B6DFF")],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                        Text("Add a Friend")
                            .font(Theme.Typography.title3(.semibold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text("Ask them for their Aria username\n(found in Friends → tap copy icon)")
                            .font(Theme.Typography.subheadline())
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: Theme.Spacing.sm) {
                        inputField(
                            icon: "at", placeholder: "Username (e.g. kfx-8472)",
                            text: $usernameInput, autocap: false
                        )
                        inputField(
                            icon: "person", placeholder: "Nickname (optional)",
                            text: $displayNameInput, autocap: true
                        )
                    }
                    .padding(.horizontal, Theme.Spacing.md)

                    Button {
                        guard !usernameInput.trimmed.isEmpty else { return }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        service.addFriend(username: usernameInput.trimmed, displayName: displayNameInput.trimmed)
                        added = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { dismiss() }
                    } label: {
                        HStack {
                            if added {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            Text(added ? "Added!" : "Add Friend")
                                .font(Theme.Typography.body(.semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(Theme.Spacing.md)
                        .background(added ? Theme.Colors.success : Theme.Colors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .disabled(usernameInput.trimmed.isEmpty || added)
                    .padding(.horizontal, Theme.Spacing.md)

                    Spacer()
                }
                .padding(.top, Theme.Spacing.xl)
            }
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
        }
    }

    private func inputField(icon: String, placeholder: String, text: Binding<String>, autocap: Bool) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.Colors.textTertiary)
                .frame(width: 20)
            TextField(placeholder, text: text)
                .font(Theme.Typography.body())
                .foregroundStyle(Theme.Colors.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(autocap ? .words : .never)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.surface.clipShape(RoundedRectangle(cornerRadius: 14)))
    }
}

// MARK: - New Group Sheet

struct NewGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = FriendsService.shared
    @State private var groupName = ""
    @State private var selectedIDs = Set<UUID>()

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    // Group name field
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "person.3.fill")
                            .foregroundStyle(Theme.Colors.primary)
                        TextField("Group name", text: $groupName)
                            .font(Theme.Typography.body())
                            .foregroundStyle(Theme.Colors.textPrimary)
                    }
                    .padding(Theme.Spacing.md)
                    .background(Theme.Colors.surface.clipShape(RoundedRectangle(cornerRadius: 14)))
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.md)

                    // Friends picker
                    if service.friends.isEmpty {
                        VStack(spacing: Theme.Spacing.md) {
                            Image(systemName: "person.2.slash")
                                .font(.system(size: 36))
                                .foregroundStyle(Theme.Colors.textTertiary)
                            Text("Add friends first to include them in a group.")
                                .font(Theme.Typography.subheadline())
                                .foregroundStyle(Theme.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 60)
                        .padding(.horizontal, Theme.Spacing.xl)
                    } else {
                        List {
                            Section {
                                ForEach(service.friends) { friend in
                                    Button {
                                        if selectedIDs.contains(friend.id) {
                                            selectedIDs.remove(friend.id)
                                        } else {
                                            selectedIDs.insert(friend.id)
                                        }
                                    } label: {
                                        HStack(spacing: Theme.Spacing.md) {
                                            avatarCircle(letter: friend.avatarLetter,
                                                         gradient: friendGradient(friend.username))
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(friend.displayName)
                                                    .font(Theme.Typography.subheadline(.medium))
                                                    .foregroundStyle(Theme.Colors.textPrimary)
                                                Text("@\(friend.username)")
                                                    .font(Theme.Typography.caption())
                                                    .foregroundStyle(Theme.Colors.textTertiary)
                                            }
                                            Spacer()
                                            if selectedIDs.contains(friend.id) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(Theme.Colors.primary)
                                            } else {
                                                Image(systemName: "circle")
                                                    .foregroundStyle(Theme.Colors.textTertiary)
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .listRowBackground(Theme.Colors.surface)
                                }
                            } header: {
                                Text("ADD FRIENDS")
                                    .font(Theme.Typography.caption(.semibold))
                                    .foregroundStyle(Theme.Colors.textTertiary)
                            }
                        }
                        .listStyle(.insetGrouped)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Create") {
                        guard !groupName.trimmed.isEmpty else { return }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        let names = service.friends
                            .filter { selectedIDs.contains($0.id) }
                            .map { $0.displayName }
                        _ = service.createGroup(name: groupName.trimmed, memberNames: names)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(groupName.trimmed.isEmpty ? Theme.Colors.textTertiary : Theme.Colors.primary)
                    .disabled(groupName.trimmed.isEmpty)
                }
            }
        }
    }
}

// MARK: - Helpers

private func avatarCircle(letter: String, gradient: LinearGradient) -> some View {
    ZStack {
        Circle()
            .fill(gradient)
            .frame(width: 44, height: 44)
        Text(letter)
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
    }
}

private func friendGradient(_ seed: String) -> LinearGradient {
    let gradients: [(Color, Color)] = [
        (Color(hex: "#4F8EF7"), Color(hex: "#9B6DFF")),
        (Color(hex: "#F97316"), Color(hex: "#EC4899")),
        (Color(hex: "#10B981"), Color(hex: "#3B82F6")),
        (Color(hex: "#F59E0B"), Color(hex: "#EF4444")),
        (Color(hex: "#8B5CF6"), Color(hex: "#06B6D4")),
    ]
    let idx = abs(seed.hashValue) % gradients.count
    return LinearGradient(colors: [gradients[idx].0, gradients[idx].1],
                          startPoint: .topLeading, endPoint: .bottomTrailing)
}
