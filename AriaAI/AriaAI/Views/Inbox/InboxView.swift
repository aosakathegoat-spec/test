import SwiftUI

struct InboxView: View {
    @StateObject private var vm = InboxViewModel()
    @EnvironmentObject private var appState: AppState
    @State private var showEmailDetail: EmailMessage?
    @State private var showConnectSheet = false

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            VStack(spacing: 0) {
                navBar
                content
            }
        }
        .sheet(isPresented: $vm.showCompose) {
            ComposeEmailView(vm: vm)
        }
        .sheet(item: $showEmailDetail) { email in
            EmailDetailView(email: email, vm: vm)
        }
        .sheet(isPresented: $showConnectSheet) {
            connectGmailSheet
        }
        .alert("Error", isPresented: Binding(
            get: { vm.error != nil && !vm.showCompose },
            set: { if !$0 { vm.error = nil } }
        )) {
            Button("OK") { vm.error = nil }
        } message: {
            Text(vm.error ?? "")
        }
        .task {
            if appState.emailService.isAuthenticated && appState.plan.canReadEmails {
                await vm.loadEmails()
            }
        }
    }

    private var navBar: some View {
        VStack(spacing: Theme.Spacing.xs) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Inbox")
                        .font(Theme.Typography.largeTitle())
                        .foregroundStyle(Theme.Colors.textPrimary)
                    if !appState.emailService.userEmail.isEmpty {
                        Text(appState.emailService.userEmail)
                            .font(Theme.Typography.caption())
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
                Spacer()
                HStack(spacing: Theme.Spacing.xs) {
                    if vm.unreadCount > 0 {
                        GlassBadge(text: "\(vm.unreadCount) unread", color: Theme.Colors.primary)
                    }
                    Button {
                        Task { await vm.loadEmails() }
                    } label: {
                        ZStack {
                            if vm.isLoading {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(Theme.Colors.textSecondary)
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Theme.Colors.textSecondary)
                            }
                        }
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                        .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.isLoading)

                    Button {
                        vm.draftEmail = DraftEmail()
                        vm.showCompose = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, Theme.Spacing.xs)

            // Search bar
            if !vm.emails.isEmpty {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .font(.system(size: 15))
                    TextField("Search emails…", text: $vm.searchText)
                        .font(Theme.Typography.body())
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .autocorrectionDisabled()
                    if !vm.searchText.isEmpty {
                        Button { vm.searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Theme.Colors.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.07))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.xs)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !appState.emailService.isAuthenticated {
            connectPrompt
        } else if !appState.plan.canReadEmails {
            upgradePrompt
        } else if vm.isLoading && vm.emails.isEmpty {
            loadingView
        } else if vm.filteredEmails.isEmpty && !vm.isLoading {
            emptyState
        } else {
            emailList
        }
    }

    private var emailList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(vm.filteredEmails.enumerated()), id: \.element.id) { index, email in
                    VStack(spacing: 0) {
                        EmailRowView(email: email)
                            .onTapGesture {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                vm.markAsRead(email)
                                showEmailDetail = email
                            }
                        if index < vm.filteredEmails.count - 1 {
                            Divider()
                                .background(Theme.Colors.separator)
                                .padding(.leading, 76)
                        }
                    }
                }
            }
            .padding(.top, Theme.Spacing.xs)
        }
        .refreshable {
            await vm.loadEmails()
        }
    }

    private var loadingView: some View {
        VStack(spacing: Theme.Spacing.md) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(Theme.Colors.primary)
                .scaleEffect(1.4)
            Text("Loading emails…")
                .font(Theme.Typography.body())
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "tray")
                .font(.system(size: 56))
                .foregroundStyle(Theme.Colors.textTertiary)
            Text(vm.searchText.isEmpty ? "No emails" : "No results for \"\(vm.searchText)\"")
                .font(Theme.Typography.title3())
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var connectPrompt: some View {
        VStack(spacing: Theme.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#DB4437").opacity(0.2), Color(hex: "#DB4437").opacity(0.05)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(width: 90, height: 90)
                Image(systemName: "envelope.badge")
                    .font(.system(size: 36))
                    .foregroundStyle(Color(hex: "#DB4437"))
            }

            VStack(spacing: Theme.Spacing.xs) {
                Text("Connect Gmail")
                    .font(Theme.Typography.title2(.bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("Connect your Gmail account to read and send emails with AI assistance.")
                    .font(Theme.Typography.body())
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xl)
            }

            GradientButton(
                title: "Connect Gmail",
                gradient: LinearGradient(
                    colors: [Color(hex: "#DB4437"), Color(hex: "#C62828")],
                    startPoint: .leading, endPoint: .trailing
                )
            ) {
                showConnectSheet = true
            }
            .padding(.horizontal, Theme.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var upgradePrompt: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "lock.shield")
                .font(.system(size: 56))
                .foregroundStyle(Theme.Colors.accent)
            Text("Upgrade to Read Emails")
                .font(Theme.Typography.title2(.bold))
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("Upgrade to Core or higher to access your inbox and let Aria help with email management.")
                .font(Theme.Typography.body())
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)
            GradientButton(
                title: "View Plans",
                gradient: Theme.Colors.gradientAccent
            ) {
                appState.showPricingSheet = true
            }
            .padding(.horizontal, Theme.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var connectGmailSheet: some View {
        NavigationStack {
            ZStack {
                SheetGlassBackground()
                VStack(spacing: Theme.Spacing.lg) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "#DB4437"), Color(hex: "#F4B400")],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                    Text("Connect Gmail")
                        .font(Theme.Typography.title(.bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("Aria will request permission to read your inbox and send emails on your behalf. Your credentials are stored securely on-device.")
                        .font(Theme.Typography.body())
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.lg)
                    GradientButton(
                        title: "Authorize with Google",
                        gradient: LinearGradient(
                            colors: [Color(hex: "#4285F4"), Color(hex: "#0F9D58")],
                            startPoint: .leading, endPoint: .trailing
                        )
                    ) {
                        Task {
                            await vm.authenticateGmail()
                            showConnectSheet = false
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                }
                .padding(.top, Theme.Spacing.xxl)
            }
            .navigationTitle("Gmail Authorization")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showConnectSheet = false }
                }
            }
        }
    }
}

struct EmailRowView: View {
    let email: EmailMessage

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: avatarColors(email.from.displayName),
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: Theme.Size.avatarSizeMd, height: Theme.Size.avatarSizeMd)
                Text(email.from.initials)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }

            // Content
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(email.from.displayName)
                        .font(Theme.Typography.subheadline(email.isRead ? .regular : .semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text(email.date.emailDateString)
                        .font(Theme.Typography.caption())
                        .foregroundStyle(Theme.Colors.textTertiary)
                    if !email.isRead {
                        Circle()
                            .fill(Theme.Colors.primary)
                            .frame(width: 8, height: 8)
                    }
                }
                Text(email.subject)
                    .font(Theme.Typography.callout(email.isRead ? .regular : .medium))
                    .foregroundStyle(email.isRead ? Theme.Colors.textSecondary : Theme.Colors.textPrimary)
                    .lineLimit(1)
                Text(email.snippet)
                    .font(Theme.Typography.footnote())
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .lineLimit(2)
                if email.hasAttachments {
                    HStack(spacing: 3) {
                        Image(systemName: "paperclip")
                            .font(.system(size: 11))
                        Text("Attachment")
                            .font(Theme.Typography.caption())
                    }
                    .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(email.isRead ? Color.clear : Color.white.opacity(0.03))
        .contentShape(Rectangle())
    }

    private func avatarColors(_ name: String) -> [Color] {
        let pairs: [[Color]] = [
            [Color(hex: "#3B82F6"), Color(hex: "#1D4ED8")],
            [Color(hex: "#8B5CF6"), Color(hex: "#6D28D9")],
            [Color(hex: "#EC4899"), Color(hex: "#BE185D")],
            [Color(hex: "#10B981"), Color(hex: "#047857")],
            [Color(hex: "#F59E0B"), Color(hex: "#B45309")],
            [Color(hex: "#EF4444"), Color(hex: "#B91C1C")],
            [Color(hex: "#6366F1"), Color(hex: "#4338CA")],
        ]
        let index = abs(name.unicodeScalars.reduce(0) { $0 + Int($1.value) }) % pairs.count
        return pairs[index]
    }
}
