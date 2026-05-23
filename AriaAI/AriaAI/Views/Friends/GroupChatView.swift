import SwiftUI
import UIKit

struct GroupChatView: View {
    @StateObject private var vm: GroupChatViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var inputFocused: Bool

    init(group: GroupConversation) {
        _vm = StateObject(wrappedValue: GroupChatViewModel(group: group))
    }

    var body: some View {
        ZStack {
            LiquidGlassBackground().ignoresSafeArea()
            VStack(spacing: 0) {
                navBar
                messageList
                inputBar
            }
        }
        .alert("Error", isPresented: Binding(
            get: { vm.error != nil },
            set: { if !$0 { vm.clearError() } }
        )) {
            Button("OK") { vm.clearError() }
        } message: {
            Text(vm.error ?? "")
        }
    }

    // MARK: - Nav bar

    private var navBar: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 2) {
                Text(vm.group.name)
                    .font(Theme.Typography.subheadline(.semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)
                Text(vm.group.memberSummary)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            // Member avatars
            memberAvatars
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.xs)
        .padding(.bottom, Theme.Spacing.sm)
    }

    @ViewBuilder
    private var memberAvatars: some View {
        let service = FriendsService.shared
        let members = vm.group.memberNames.prefix(3)
        ZStack(alignment: .trailing) {
            ForEach(Array(members.reversed().enumerated()), id: \.offset) { i, name in
                let friend = service.friends.first(where: { $0.displayName == name })
                let letter = friend?.avatarLetter ?? String(name.prefix(1)).uppercased()
                let gradient = friendGradient(name)
                ZStack {
                    Circle().fill(gradient).frame(width: 28, height: 28)
                    Text(letter)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
                .offset(x: CGFloat(i) * -16)
            }
        }
        .frame(width: CGFloat(min(members.count, 3)) * 16 + 28)
    }

    // MARK: - Message list

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.sm) {
                    ForEach(vm.messages) { msg in
                        MessageBubbleView(message: msg)
                            .padding(.horizontal, Theme.Spacing.md)
                            .id(msg.id)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.vertical, Theme.Spacing.sm)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: vm.scrollToBottom) { _, val in
                guard val else { return }
                withAnimation(Theme.Animation.smooth) { proxy.scrollTo("bottom", anchor: .bottom) }
                vm.scrollToBottom = false
            }
            .onChange(of: vm.messages.count) { old, new in
                guard new > old else { return }
                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("bottom", anchor: .bottom) }
            }
        }
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: Theme.Spacing.xs) {
            HStack(alignment: .bottom, spacing: 0) {
                TextField("", text: $vm.inputText, axis: .vertical)
                    .placeholder(when: vm.inputText.isEmpty) {
                        Text("Message the group…")
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                    .font(Theme.Typography.body())
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1...6)
                    .focused($inputFocused)
                    .onSubmit {
                        guard !vm.isStreaming else { return }
                        Task { await vm.sendMessage() }
                    }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.07))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1))
            )

            Group {
                if vm.isStreaming {
                    Button { vm.cancelStreaming() } label: {
                        ZStack {
                            Circle().fill(Color(hex: "#EF4444")).frame(width: 38, height: 38)
                            RoundedRectangle(cornerRadius: 3).fill(.white).frame(width: 13, height: 13)
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        Task { await vm.sendMessage() }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [Color(hex: "#4F8EF7"), Color(hex: "#7C3AED")],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ).erased)
                                .frame(width: 38, height: 38)
                            Image(systemName: "arrow.up")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.inputText.trimmed.isEmpty)
                    .opacity(vm.inputText.trimmed.isEmpty ? 0.4 : 1)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: vm.isStreaming)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .padding(.bottom, 4)
        .background(.ultraThinMaterial)
        .environment(\.colorScheme, .dark)
        .overlay(alignment: .top) { Divider().opacity(0.3) }
    }
}
