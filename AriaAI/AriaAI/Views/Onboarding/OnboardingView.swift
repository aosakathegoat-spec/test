import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @State private var currentPage = 0
    @State private var name = ""
    @State private var isAnimating = false
    @FocusState private var nameFocused: Bool

    private let pages: [OnboardingPage] = [
        .init(
            icon: "sparkles",
            gradient: [Color(hex: "#4F8EF7"), Color(hex: "#9B6DFF")],
            title: "Meet Aria",
            subtitle: "Your intelligent AI assistant powered by Claude. Chat, manage emails, and start every day informed."
        ),
        .init(
            icon: "envelope.open.fill",
            gradient: [Color(hex: "#EC4899"), Color(hex: "#8B5CF6")],
            title: "Smart Email",
            subtitle: "Read your inbox, draft replies with AI, and send emails—all from one place."
        ),
        .init(
            icon: "waveform",
            gradient: [Color(hex: "#10B981"), Color(hex: "#3B82F6")],
            title: "Voice Mode",
            subtitle: "Talk to Aria naturally. She listens, responds, and can read your morning briefing aloud."
        ),
        .init(
            icon: "sun.horizon.fill",
            gradient: [Color(hex: "#FCD34D"), Color(hex: "#F97316")],
            title: "Morning Briefing",
            subtitle: "Wake up to a personalized briefing with your email highlights and insights for the day."
        ),
    ]

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            VStack(spacing: 0) {
                // Page indicator
                HStack(spacing: 6) {
                    ForEach(0..<pages.count + 1, id: \.self) { i in
                        Capsule()
                            .fill(currentPage == i ? Theme.Colors.primary : Color.white.opacity(0.25))
                            .frame(width: currentPage == i ? 24 : 6, height: 6)
                            .animation(Theme.Animation.spring, value: currentPage)
                    }
                }
                .padding(.top, Theme.Spacing.xl)

                Spacer()

                if currentPage < pages.count {
                    featurePage(pages[currentPage])
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                        .id(currentPage)
                } else {
                    nameEntryPage
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }

                Spacer()

                // Navigation
                VStack(spacing: Theme.Spacing.sm) {
                    if currentPage < pages.count {
                        Button {
                            withAnimation(Theme.Animation.spring) { currentPage += 1 }
                        } label: {
                            HStack {
                                Text("Continue")
                                    .font(Theme.Typography.body(.semibold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: Theme.Size.buttonHeight)
                            .background(
                                LinearGradient(
                                    colors: pages[currentPage].gradient,
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadiusSm))
                            .shadow(color: pages[currentPage].gradient.first?.opacity(0.4) ?? .clear, radius: 12, x: 0, y: 6)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, Theme.Spacing.xl)
                    }

                    if currentPage > 0 {
                        Button("Back") {
                            withAnimation(Theme.Animation.spring) { currentPage -= 1 }
                        }
                        .font(Theme.Typography.subheadline(.medium))
                        .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
                .padding(.bottom, Theme.Spacing.xxl)
            }
        }
        .onAppear { isAnimating = true }
    }

    private func featurePage(_ page: OnboardingPage) -> some View {
        VStack(spacing: Theme.Spacing.xl) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [page.gradient.first!.opacity(0.3), .clear],
                            center: .center, startRadius: 0, endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)

                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: page.gradient,
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)

                    Image(systemName: page.icon)
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .shadow(color: page.gradient.first!.opacity(0.5), radius: 20, x: 0, y: 8)
                .scaleEffect(isAnimating ? 1 : 0.7)
                .animation(Theme.Animation.spring.delay(0.1), value: isAnimating)
            }

            VStack(spacing: Theme.Spacing.sm) {
                Text(page.title)
                    .font(Theme.Typography.largeTitle(.bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(Theme.Typography.body())
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xl)
            }
        }
    }

    private var nameEntryPage: some View {
        VStack(spacing: Theme.Spacing.xl) {
            // Aria logo
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#4F8EF7"), Color(hex: "#9B6DFF")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                Text("A")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .shadow(color: Color(hex: "#4F8EF7").opacity(0.5), radius: 20)

            VStack(spacing: Theme.Spacing.sm) {
                Text("What's your name?")
                    .font(Theme.Typography.largeTitle(.bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("Aria will use this to personalize your experience.")
                    .font(Theme.Typography.body())
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Name input
            TextField("Your name", text: $name)
                .font(.system(size: 24, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .focused($nameFocused)
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.vertical, Theme.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Glass.cornerRadiusSm)
                        .fill(Color.white.opacity(0.07))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Glass.cornerRadiusSm)
                                .stroke(
                                    nameFocused
                                        ? Theme.Colors.gradientPrimary
                                        : LinearGradient(colors: [.white.opacity(0.15)], startPoint: .leading, endPoint: .trailing),
                                    lineWidth: nameFocused ? 2 : 1
                                )
                        )
                )
                .padding(.horizontal, Theme.Spacing.xl)
                .onAppear { nameFocused = true }

            // Get started button
            GradientButton(
                title: "Get Started",
                gradient: Theme.Colors.gradientPrimary
            ) {
                appState.completeOnboarding(name: name)
            }
            .padding(.horizontal, Theme.Spacing.xl)
        }
    }
}

struct OnboardingPage {
    let icon: String
    let gradient: [Color]
    let title: String
    let subtitle: String
}
