import SwiftUI
import AVFoundation

struct SettingsView: View {
    @StateObject private var vm = SettingsViewModel()
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var auth: AuthService
    @State private var showPricing = false
    @State private var showVoicePicker = false
    @State private var showSignOutConfirm = false
    @State private var showGmailConnect = false

    var body: some View {
        ZStack {
            LiquidGlassBackground()
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    profileSection
                    tokenUsageSection
                    planSection
                    apiKeySection
                    voiceSection
                    emailSection
                    morningBriefingSection
                    aboutSection
                }
                .padding(Theme.Spacing.md)
                .padding(.bottom, 100)
            }
        }
        .sheet(isPresented: $showPricing) { PricingView() }
        .sheet(isPresented: $showVoicePicker) { voicePickerSheet }
        .sheet(isPresented: $showGmailConnect) { gmailConnectSheet }
    }

    // MARK: - Profile
    private var profileSection: some View {
        AriaGlassCard {
            HStack(spacing: Theme.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#4F8EF7"), Color(hex: "#9B6DFF")],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                    Text(vm.userName.initials.isEmpty ? "A" : vm.userName.initials)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Your name", text: $vm.userName)
                        .font(Theme.Typography.title3(.semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .onSubmit { vm.saveUserName() }
                    HStack(spacing: 6) {
                        GlassBadge(text: vm.plan.displayName, color: vm.plan.accentColor)
                        if !appState.emailService.userEmail.isEmpty {
                            Text(appState.emailService.userEmail)
                                .font(Theme.Typography.caption())
                                .foregroundStyle(Theme.Colors.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer()
            }
        }
    }

    // MARK: - Token Usage
    private var tokenUsageSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionHeader("Usage")
            TokenUsageBar(usage: vm.usage, plan: vm.plan)
        }
    }

    // MARK: - Plan
    private var planSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionHeader("Subscription")
            AriaGlassCard {
                VStack(spacing: Theme.Spacing.md) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current Plan")
                                .font(Theme.Typography.footnote())
                                .foregroundStyle(Theme.Colors.textSecondary)
                            Text(vm.plan.displayName)
                                .font(Theme.Typography.title3(.bold))
                                .foregroundStyle(vm.plan.accentColor)
                        }
                        Spacer()
                        if vm.plan != .ultra {
                            GradientButton(
                                title: "Upgrade",
                                gradient: Theme.Colors.gradientAccent,
                                fullWidth: false
                            ) { showPricing = true }
                        }
                    }

                    Divider().opacity(0.2)

                    settingsRow(icon: "arrow.clockwise", label: "Restore Purchases") {
                        Task { await vm.restorePurchases() }
                    }
                    settingsRow(icon: "doc.text", label: "Privacy Policy") {
                        if let url = URL(string: "https://aria-assistant.app/privacy") {
                            UIApplication.shared.open(url)
                        }
                    }
                    settingsRow(icon: "doc.badge.gearshape", label: "Terms of Service") {
                        if let url = URL(string: "https://aria-assistant.app/terms") {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            }
        }
    }

    // MARK: - API Key
    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionHeader("Anthropic API Key")
            AriaGlassCard {
                VStack(spacing: Theme.Spacing.sm) {
                    Text("Enter your Anthropic API key to use Aria. Keys are stored securely on-device and never sent to our servers.")
                        .font(Theme.Typography.footnote())
                        .foregroundStyle(Theme.Colors.textSecondary)

                    HStack {
                        Group {
                            if vm.showAPIKey {
                                TextField("sk-ant-…", text: $vm.apiKeyInput)
                            } else {
                                SecureField("sk-ant-…", text: $vm.apiKeyInput)
                            }
                        }
                        .font(Theme.Typography.footnote(.regular))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .autocorrectionDisabled()
                        .autocapitalization(.none)
                        .textContentType(.password)

                        Button {
                            vm.showAPIKey.toggle()
                        } label: {
                            Image(systemName: vm.showAPIKey ? "eye.slash" : "eye")
                                .font(.system(size: 16))
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(Theme.Spacing.sm)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )

                    HStack(spacing: Theme.Spacing.sm) {
                        GradientButton(
                            title: vm.apiKeySaved ? "Saved!" : "Save Key",
                            gradient: vm.apiKeySaved
                                ? LinearGradient(colors: [Theme.Colors.success, Theme.Colors.success], startPoint: .leading, endPoint: .trailing)
                                : Theme.Colors.gradientPrimary
                        ) {
                            vm.saveAPIKey()
                        }

                        if !vm.apiKeyInput.isEmpty {
                            Button("Clear") { vm.clearAPIKey() }
                                .font(Theme.Typography.subheadline(.medium))
                                .foregroundStyle(Theme.Colors.error)
                                .frame(height: Theme.Size.buttonHeight)
                                .padding(.horizontal, Theme.Spacing.md)
                                .background(Theme.Colors.error.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadiusSm))
                                .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Voice
    private var voiceSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionHeader("Voice")
            AriaGlassCard {
                VStack(spacing: 0) {
                    Button {
                        showVoicePicker = true
                    } label: {
                        HStack {
                            Image(systemName: "waveform")
                                .foregroundStyle(Theme.Colors.primary)
                                .frame(width: 24)
                            Text("Voice")
                                .font(Theme.Typography.body())
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Spacer()
                            let voice = appState.voiceService.availableVoices
                                .first { $0.id == vm.selectedVoiceID }?.name
                                ?? "Default"
                            Text(voice)
                                .font(Theme.Typography.subheadline())
                                .foregroundStyle(Theme.Colors.textSecondary)
                                .lineLimit(1)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.Colors.textTertiary)
                        }
                        .padding(.vertical, Theme.Spacing.sm)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Email
    private var emailSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionHeader("Email")
            AriaGlassCard {
                if appState.emailService.isAuthenticated {
                    VStack(spacing: Theme.Spacing.sm) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.Colors.success)
                            Text("Gmail Connected")
                                .font(Theme.Typography.body())
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Spacer()
                            Text(appState.emailService.userEmail)
                                .font(Theme.Typography.caption())
                                .foregroundStyle(Theme.Colors.textSecondary)
                                .lineLimit(1)
                        }
                        Button("Disconnect Gmail") {
                            appState.emailService.disconnect()
                        }
                        .font(Theme.Typography.subheadline(.medium))
                        .foregroundStyle(Theme.Colors.error)
                    }
                } else {
                    settingsRow(icon: "envelope", label: "Connect Gmail") {
                        showGmailConnect = true
                    }
                }
            }
        }
    }

    // MARK: - Morning Briefing
    private var morningBriefingSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionHeader("Morning Briefing")
            AriaGlassCard {
                VStack(spacing: Theme.Spacing.sm) {
                    HStack {
                        Image(systemName: "sun.horizon")
                            .foregroundStyle(Color(hex: "#FCD34D"))
                            .frame(width: 24)
                        Text("Daily Briefing")
                            .font(Theme.Typography.body())
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Spacer()
                        Toggle("", isOn: $vm.morningBriefingEnabled)
                            .tint(Theme.Colors.primary)
                            .onChange(of: vm.morningBriefingEnabled) { _, _ in
                                vm.saveMorningBriefingSettings()
                            }
                    }
                    if vm.morningBriefingEnabled {
                        Divider().opacity(0.2)
                        DatePicker(
                            "Time",
                            selection: Binding(
                                get: {
                                    var comps = DateComponents()
                                    comps.hour = vm.briefingHour
                                    comps.minute = vm.briefingMinute
                                    return Calendar.current.date(from: comps) ?? Date()
                                },
                                set: { date in
                                    let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
                                    vm.briefingHour = comps.hour ?? 7
                                    vm.briefingMinute = comps.minute ?? 0
                                    vm.saveMorningBriefingSettings()
                                }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                        .font(Theme.Typography.body())
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .tint(Theme.Colors.primary)
                    }
                }
            }
            .disabled(!vm.plan.hasMorningBriefing)
            .opacity(vm.plan.hasMorningBriefing ? 1 : 0.5)
            if !vm.plan.hasMorningBriefing {
                Text("Upgrade to Pro or Ultra to access morning briefings.")
                    .font(Theme.Typography.caption())
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - About
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionHeader("About")
            AriaGlassCard {
                VStack(spacing: 0) {
                    settingsRowStatic(icon: "sparkle",    label: "Version",    value: "1.0.0")
                    Divider().opacity(0.15).padding(.vertical, Theme.Spacing.xs)
                    settingsRowStatic(icon: "cpu",        label: "Model",      value: "claude-haiku-4-5")
                    Divider().opacity(0.15).padding(.vertical, Theme.Spacing.xs)
                    settingsRowStatic(icon: "building.2", label: "Powered by", value: "Anthropic")
                }
            }

            // Sign out
            Button {
                showSignOutConfirm = true
            } label: {
                Text("Sign Out")
                    .font(Theme.Typography.body(.medium))
                    .foregroundStyle(Theme.Colors.error)
                    .frame(maxWidth: .infinity)
                    .frame(height: Theme.Size.buttonHeight)
                    .background(Theme.Colors.error.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadiusSm))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Glass.cornerRadiusSm)
                            .stroke(Theme.Colors.error.opacity(0.2), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .confirmationDialog("Sign Out", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) { auth.signOut() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You'll need to sign in again to use Aria.")
            }
        }
    }

    // MARK: - Helpers
    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(Theme.Typography.caption(.semibold))
            .foregroundStyle(Theme.Colors.textTertiary)
            .padding(.horizontal, 4)
    }

    private func settingsRow(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(width: 24)
                Text(label)
                    .font(Theme.Typography.body())
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            .padding(.vertical, Theme.Spacing.xs)
        }
        .buttonStyle(.plain)
    }

    private func settingsRowStatic(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(width: 24)
            Text(label)
                .font(Theme.Typography.body())
                .foregroundStyle(Theme.Colors.textPrimary)
            Spacer()
            Text(value)
                .font(Theme.Typography.subheadline())
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    // MARK: - Voice Picker Sheet
    private var voicePickerSheet: some View {
        NavigationStack {
            ZStack {
                SheetGlassBackground()
                List {
                    ForEach(appState.voiceService.availableVoices) { voice in
                        Button {
                            vm.saveVoiceSelection(voice.id)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(voice.name)
                                        .font(Theme.Typography.body())
                                        .foregroundStyle(Theme.Colors.textPrimary)
                                    Text(qualityLabel(voice.quality))
                                        .font(Theme.Typography.caption())
                                        .foregroundStyle(qualityColor(voice.quality))
                                }
                                Spacer()
                                if voice.id == vm.selectedVoiceID {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Theme.Colors.primary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .leading) {
                            Button {
                                vm.previewVoice(voice.id)
                            } label: {
                                Label("Preview", systemImage: "play.fill")
                            }
                            .tint(Theme.Colors.primary)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Choose Voice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showVoicePicker = false }
                }
            }
        }
    }

    private func qualityLabel(_ quality: AVSpeechSynthesisVoiceQuality) -> String {
        switch quality {
        case .premium:  return "Premium"
        case .enhanced: return "Enhanced"
        default:        return "Standard"
        }
    }

    private func qualityColor(_ quality: AVSpeechSynthesisVoiceQuality) -> Color {
        switch quality {
        case .premium:  return Color(hex: "#FCD34D")
        case .enhanced: return Theme.Colors.primary
        default:        return Theme.Colors.textTertiary
        }
    }

    // MARK: - Gmail Connect Sheet
    private var gmailConnectSheet: some View {
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
                            try? await appState.emailService.authenticate()
                            showGmailConnect = false
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
                    Button("Cancel") { showGmailConnect = false }
                }
            }
        }
    }
}
