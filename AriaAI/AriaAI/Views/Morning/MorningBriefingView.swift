import SwiftUI

struct MorningBriefingView: View {
    @StateObject private var vm = MorningBriefingViewModel()
    @EnvironmentObject private var appState: AppState
    @State private var showScheduler = false

    var body: some View {
        ZStack {
            LiquidGlassBackground()
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    header
                    briefingContent
                    scheduleCard
                }
                .padding(Theme.Spacing.md)
            }
        }
        .sheet(isPresented: $showScheduler) { schedulerSheet }
        .onAppear { vm.setup(appState: appState) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(greetingText)
                        .font(Theme.Typography.largeTitle(.bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(todayDateString)
                        .font(Theme.Typography.subheadline())
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer()
                sunIcon
            }
        }
    }

    private var sunIcon: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "#FCD34D").opacity(0.4), .clear],
                        center: .center, startRadius: 0, endRadius: 50
                    )
                )
                .frame(width: 80, height: 80)
            Image(systemName: hourOfDay >= 18 || hourOfDay < 6 ? "moon.stars.fill" : "sun.max.fill")
                .font(.system(size: 40))
                .foregroundStyle(
                    LinearGradient(
                        colors: hourOfDay >= 18 || hourOfDay < 6
                            ? [Color(hex: "#818CF8"), Color(hex: "#C4B5FD")]
                            : [Color(hex: "#FCD34D"), Color(hex: "#F59E0B")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color(hex: "#FCD34D").opacity(0.4), radius: 10)
        }
    }

    @ViewBuilder
    private var briefingContent: some View {
        if !appState.plan.hasMorningBriefing {
            upgradeCard
        } else if vm.isGenerating {
            generatingCard
        } else if let briefing = vm.briefing {
            briefingCard(briefing)
        } else {
            generateCard
        }
    }

    private var generateCard: some View {
        AriaGlassCard {
            VStack(spacing: Theme.Spacing.md) {
                Image(systemName: "sunrise.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#FCD34D"), Color(hex: "#F97316")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                Text("Your Morning Briefing")
                    .font(Theme.Typography.title2(.bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("Aria will generate a personalized briefing with email highlights and useful insights for your day.")
                    .font(Theme.Typography.body())
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                GradientButton(
                    title: "Generate Briefing",
                    gradient: LinearGradient(
                        colors: [Color(hex: "#FCD34D"), Color(hex: "#F97316")],
                        startPoint: .leading, endPoint: .trailing
                    )
                ) {
                    Task { await vm.generate() }
                }
            }
        }
    }

    private var generatingCard: some View {
        AriaGlassCard {
            VStack(spacing: Theme.Spacing.lg) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 3)
                        .frame(width: 60, height: 60)
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "#FCD34D"), Color(hex: "#F97316")],
                                startPoint: .leading, endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(vm.spinAngle))
                        .onAppear {
                            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                                vm.spinAngle = 360
                            }
                        }
                }
                Text("Crafting your briefing…")
                    .font(Theme.Typography.body(.medium))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.lg)
        }
    }

    private func briefingCard(_ text: String) -> some View {
        AriaGlassCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14))
                        Text("Today's Briefing")
                            .font(Theme.Typography.footnote(.semibold))
                    }
                    .foregroundStyle(Color(hex: "#FCD34D"))
                    Spacer()
                    if let last = vm.lastGenerated {
                        Text(last.shortTimeString)
                            .font(Theme.Typography.caption())
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                }

                Text(text)
                    .font(Theme.Typography.body())
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: Theme.Spacing.sm) {
                    // Play/Stop TTS
                    Button {
                        if appState.voiceService.isSpeaking {
                            appState.voiceService.stop()
                        } else {
                            appState.voiceService.speak(text)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: appState.voiceService.isSpeaking ? "stop.fill" : "play.fill")
                                .font(.system(size: 13))
                            Text(appState.voiceService.isSpeaking ? "Stop" : "Listen")
                                .font(Theme.Typography.subheadline(.medium))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(
                            LinearGradient(
                                colors: appState.voiceService.isSpeaking
                                    ? [Color(hex: "#EF4444"), Color(hex: "#DC2626")]
                                    : [Color(hex: "#FCD34D"), Color(hex: "#F97316")],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task { await vm.generate() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 13))
                            Text("Refresh")
                                .font(Theme.Typography.subheadline(.medium))
                        }
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(Color.white.opacity(0.07))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var upgradeCard: some View {
        AriaGlassCard {
            VStack(spacing: Theme.Spacing.md) {
                Image(systemName: "sun.horizon.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#FCD34D"), Color(hex: "#F97316")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                Text("Morning Briefing")
                    .font(Theme.Typography.title2(.bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("Upgrade to Pro or Ultra to get personalized daily briefings with AI-generated summaries of your emails and insights.")
                    .font(Theme.Typography.body())
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                GradientButton(
                    title: "Upgrade to Pro",
                    gradient: Theme.Colors.gradientAccent
                ) {
                    appState.showPricingSheet = true
                }
            }
        }
    }

    private var scheduleCard: some View {
        AriaGlassCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack {
                    Label("Daily Schedule", systemImage: "bell.badge")
                        .font(Theme.Typography.subheadline(.semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Spacer()
                    Toggle("", isOn: $vm.isScheduled)
                        .tint(Theme.Colors.primary)
                        .onChange(of: vm.isScheduled) { _, on in
                            vm.updateSchedule(enabled: on)
                        }
                }

                if vm.isScheduled {
                    HStack {
                        Image(systemName: "alarm")
                            .foregroundStyle(Theme.Colors.textSecondary)
                        Text("Briefing at \(vm.timeFormatted)")
                            .font(Theme.Typography.body())
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Spacer()
                        Button("Change") { showScheduler = true }
                            .font(Theme.Typography.subheadline(.medium))
                            .foregroundStyle(Theme.Colors.primary)
                    }
                } else {
                    Text("Enable to receive a daily morning briefing notification.")
                        .font(Theme.Typography.footnote())
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
        }
        .disabled(!appState.plan.hasMorningBriefing)
        .opacity(appState.plan.hasMorningBriefing ? 1 : 0.5)
    }

    private var schedulerSheet: some View {
        NavigationStack {
            ZStack {
                SheetGlassBackground()
                VStack(spacing: Theme.Spacing.lg) {
                    Text("Set Briefing Time")
                        .font(Theme.Typography.title(.bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    DatePicker("", selection: $vm.scheduledTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .colorScheme(.dark)
                    GradientButton(
                        title: "Save Schedule",
                        gradient: Theme.Colors.gradientPrimary
                    ) {
                        vm.saveScheduledTime()
                        showScheduler = false
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                }
                .padding(Theme.Spacing.lg)
            }
            .presentationDetents([.medium])
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showScheduler = false }
                }
            }
        }
    }

    private var greetingText: String {
        switch hourOfDay {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default:      return "Good night"
        }
    }

    private var todayDateString: String {
        DateFormatter.localizedString(from: Date(), dateStyle: .full, timeStyle: .none)
    }

    private var hourOfDay: Int {
        Calendar.current.component(.hour, from: Date())
    }
}

@MainActor
class MorningBriefingViewModel: ObservableObject {
    @Published var briefing: String?
    @Published var isGenerating = false
    @Published var lastGenerated: Date?
    @Published var isScheduled = false
    @Published var scheduledTime = Date()
    @Published var spinAngle: Double = 0

    private var appState: AppState?
    private let briefingService = MorningBriefingService.shared
    private let inboxVM = InboxViewModel()

    func setup(appState: AppState) {
        self.appState = appState
        isScheduled = briefingService.isScheduled
        var components = Calendar.current.dateComponents([.hour, .minute], from: Date())
        components.hour   = briefingService.scheduledHour
        components.minute = briefingService.scheduledMinute
        scheduledTime = Calendar.current.date(from: components) ?? Date()
    }

    func generate() async {
        guard let appState, appState.plan.hasMorningBriefing else { return }
        isGenerating = true
        do {
            let emails = (try? await EmailService.shared.fetchInbox(maxResults: 10)) ?? []
            briefing = try await briefingService.generateBriefing(emails: emails)
            lastGenerated = Date()
        } catch {
            appState.showError(error.localizedDescription)
        }
        isGenerating = false
    }

    func updateSchedule(enabled: Bool) {
        if enabled {
            let h = Calendar.current.component(.hour,   from: scheduledTime)
            let m = Calendar.current.component(.minute, from: scheduledTime)
            briefingService.scheduleDailyBriefing(hour: h, minute: m)
        } else {
            briefingService.cancelDailyBriefing()
        }
    }

    func saveScheduledTime() {
        let h = Calendar.current.component(.hour,   from: scheduledTime)
        let m = Calendar.current.component(.minute, from: scheduledTime)
        briefingService.scheduleDailyBriefing(hour: h, minute: m)
        isScheduled = true
    }

    var timeFormatted: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: scheduledTime)
    }
}
