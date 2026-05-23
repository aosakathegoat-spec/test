import SwiftUI
import StoreKit

struct PricingView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var purchaseService = PurchaseService.shared
    @ObservedObject private var tokenTracker = TokenTracker.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan: SubscriptionPlan = .pro
    @State private var isPurchasing = false
    @State private var purchaseError: String?
    @State private var showSuccessAnimation = false
    @State private var successEntered = false

    var body: some View {
        ZStack {
            SheetGlassBackground()

            if showSuccessAnimation {
                successOverlay
            } else {
                mainContent
            }
        }
        .onAppear {
            switch tokenTracker.plan {
            case .free:  selectedPlan = .core
            case .core:  selectedPlan = .pro
            case .pro:   selectedPlan = .ultra
            case .ultra: selectedPlan = .ultra
            }
        }
    }

    private var mainContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Theme.Spacing.lg) {
                // Header
                VStack(spacing: Theme.Spacing.xs) {
                    Text("✦")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "#FCD34D"), Color(hex: "#F97316")],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                    Text("Upgrade Aria")
                        .font(Theme.Typography.largeTitle(.bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("Unlock the full power of your AI assistant")
                        .font(Theme.Typography.body())
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, Theme.Spacing.lg)

                // Plan cards
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(SubscriptionPlan.allCases, id: \.self) { plan in
                        PlanCardView(
                            plan: plan,
                            isSelected: selectedPlan == plan,
                            isCurrent: tokenTracker.plan == plan,
                            priceString: purchaseService.priceString(for: plan)
                        ) {
                            let gen = UIImpactFeedbackGenerator(style: .light)
                            gen.prepare()
                            gen.impactOccurred()
                            withAnimation(Theme.Animation.spring) { selectedPlan = plan }
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.xs)

                // Feature comparison
                featureComparison

                // CTA
                ctaButton

                // Legal
                VStack(spacing: 4) {
                    Text("Subscription auto-renews monthly. Cancel anytime in App Store settings.")
                        .font(Theme.Typography.caption())
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .multilineTextAlignment(.center)
                    Button("Restore Purchases") {
                        Task {
                            do {
                                try await purchaseService.restorePurchases()
                            } catch {
                                purchaseError = error.localizedDescription
                            }
                        }
                    }
                    .font(Theme.Typography.caption(.medium))
                    .foregroundStyle(Theme.Colors.primary)
                    .buttonStyle(.plain)
                }
                .padding(.bottom, Theme.Spacing.xl)
            }
            .padding(.horizontal, Theme.Spacing.md)
        }
    }

    private var featureComparison: some View {
        AriaGlassCard {
            VStack(spacing: Theme.Spacing.sm) {
                Text("What's included")
                    .font(Theme.Typography.subheadline(.semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(selectedPlan.features) { feature in
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: feature.included ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(feature.included ? Theme.Colors.success : Theme.Colors.textTertiary)
                            .font(.system(size: 16))
                            .animation(.easeInOut(duration: 0.2), value: feature.included)
                        Image(systemName: feature.icon)
                            .foregroundStyle(feature.included ? Theme.Colors.textPrimary : Theme.Colors.textTertiary)
                            .frame(width: 18)
                            .animation(.easeInOut(duration: 0.2), value: feature.included)
                        Text(feature.title)
                            .font(Theme.Typography.body())
                            .foregroundStyle(feature.included ? Theme.Colors.textPrimary : Theme.Colors.textTertiary)
                            .animation(.easeInOut(duration: 0.2), value: feature.included)
                        Spacer()
                    }
                }
            }
        }
    }

    private var ctaButton: some View {
        VStack(spacing: Theme.Spacing.sm) {
            if let error = purchaseError {
                Text(error)
                    .font(Theme.Typography.footnote())
                    .foregroundStyle(Theme.Colors.error)
                    .multilineTextAlignment(.center)
            }

            if selectedPlan == .free || selectedPlan == tokenTracker.plan {
                Button(selectedPlan == .free ? "Stay on Free" : "Keep \(selectedPlan.displayName)") {
                    dismiss()
                }
                .font(Theme.Typography.body(.medium))
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: Theme.Size.buttonHeight)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadiusSm))
                .buttonStyle(.plain)
            } else if isPlanDowngrade(selectedPlan) {
                VStack(spacing: Theme.Spacing.xs) {
                    Button("Manage in App Store") {
                        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(Theme.Typography.body(.medium))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: Theme.Size.buttonHeight)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadiusSm))
                    .buttonStyle(.plain)
                    Text("To downgrade, manage your subscription in the App Store.")
                        .font(Theme.Typography.caption())
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .multilineTextAlignment(.center)
                }
            } else {
                GradientButton(
                    title: isPurchasing
                        ? "Processing…"
                        : "Get \(selectedPlan.displayName) · \(purchaseService.priceString(for: selectedPlan))",
                    gradient: LinearGradient(
                        colors: selectedPlan.gradientColors,
                        startPoint: .leading, endPoint: .trailing
                    ),
                    isLoading: isPurchasing
                ) {
                    Task { await purchase(selectedPlan) }
                }
                .disabled(isPurchasing)
            }
        }
    }

    private var successOverlay: some View {
        VStack(spacing: Theme.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.success.opacity(0.2))
                    .frame(width: 100, height: 100)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(Theme.Colors.success)
            }
            .scaleEffect(successEntered ? 1 : 0.5)
            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: successEntered)
            .onAppear { successEntered = true }

            Text("Welcome to \(selectedPlan.displayName)!")
                .font(Theme.Typography.title(.bold))
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("You now have access to \(selectedPlan.tokenLimitDisplay) and all \(selectedPlan.displayName) features.")
                .font(Theme.Typography.body())
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)
            Button("Start Using Aria") { dismiss() }
                .font(Theme.Typography.body(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: Theme.Size.buttonHeight)
                .background(
                    LinearGradient(
                        colors: selectedPlan.gradientColors,
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadiusSm))
                .buttonStyle(.plain)
                .padding(.horizontal, Theme.Spacing.xl)
        }
        .padding(Theme.Spacing.lg)
    }

    private func isPlanDowngrade(_ plan: SubscriptionPlan) -> Bool {
        let all = SubscriptionPlan.allCases
        guard let currentIdx = all.firstIndex(of: tokenTracker.plan),
              let selectedIdx = all.firstIndex(of: plan) else { return false }
        return selectedIdx < currentIdx
    }

    private func purchase(_ plan: SubscriptionPlan) async {
        guard !isPurchasing else { return }
        isPurchasing = true
        purchaseError = nil
        do {
            let success = try await purchaseService.purchase(plan)
            if success {
                successEntered = false
                withAnimation { showSuccessAnimation = true }
            }
        } catch {
            purchaseError = error.localizedDescription
        }
        isPurchasing = false
    }
}

struct PlanCardView: View {
    let plan: SubscriptionPlan
    let isSelected: Bool
    let isCurrent: Bool
    let priceString: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Theme.Spacing.md) {
                // Plan icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: plan.gradientColors,
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    Image(systemName: planIcon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(plan.displayName)
                            .font(Theme.Typography.subheadline(.bold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        if plan.isPopular {
                            Text("POPULAR")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    LinearGradient(
                                        colors: plan.gradientColors,
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .clipShape(Capsule())
                        }
                        if isCurrent {
                            Text("ACTIVE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Theme.Colors.success)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.Colors.success.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                    Text(plan.tagline)
                        .font(Theme.Typography.caption())
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(plan == .free ? "Free" : priceString.components(separatedBy: "/").first ?? priceString)
                        .font(Theme.Typography.subheadline(.bold))
                        .foregroundStyle(isSelected ? plan.accentColor : Theme.Colors.textPrimary)
                    if plan != .free {
                        Text("per month")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                }
            }
            .padding(Theme.Spacing.md)
            .background {
                RoundedRectangle(cornerRadius: Theme.Glass.cornerRadiusSm, style: .continuous)
                    .fill(Material.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Glass.cornerRadiusSm, style: .continuous)
                    .stroke(
                        isSelected
                            ? LinearGradient(colors: plan.gradientColors, startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
            .shadow(
                color: isSelected ? plan.accentColor.opacity(0.2) : .clear,
                radius: 8, x: 0, y: 4
            )
        }
        .buttonStyle(.plain)
    }

    private var planIcon: String {
        switch plan {
        case .free:  return "sparkle"
        case .core:  return "bolt.fill"
        case .pro:   return "star.fill"
        case .ultra: return "crown.fill"
        }
    }
}
