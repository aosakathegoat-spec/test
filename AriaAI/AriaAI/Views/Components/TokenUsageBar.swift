import SwiftUI

struct TokenUsageBar: View {
    let usage: TokenUsage
    let plan: SubscriptionPlan
    var compact: Bool = false

    private var overallPercent: Double {
        usage.usagePercent(limit: plan.tokenLimit)
    }

    var body: some View {
        if compact {
            compactBar
        } else {
            fullBar
        }
    }

    private var fullBar: some View {
        AriaGlassCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Daily Token Usage")
                            .font(Theme.Typography.title3(.semibold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text(usage.timeUntilReset)
                            .font(Theme.Typography.caption())
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    Spacer()
                    GlassBadge(
                        text: plan.displayName,
                        color: plan.accentColor
                    )
                }

                // Main progress bar
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    HStack {
                        Text("\(usage.totalTokens.tokenFormatted) / \(plan.tokenLimit.tokenFormatted)")
                            .font(Theme.Typography.subheadline(.medium))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Spacer()
                        Text("\(Int(overallPercent * 100))%")
                            .font(Theme.Typography.subheadline(.semibold))
                            .foregroundStyle(barColor)
                    }

                    // Segmented bar (input + output)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            // Background track
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                                .frame(height: 10)

                            HStack(spacing: 0) {
                                // Input tokens (blue)
                                RoundedRectangle(cornerRadius: 0)
                                    .fill(Color(hex: "#3B82F6"))
                                    .frame(
                                        width: geo.size.width * CGFloat(usage.inputPercent) * CGFloat(overallPercent),
                                        height: 10
                                    )

                                // Output tokens (purple)
                                RoundedRectangle(cornerRadius: 0)
                                    .fill(Color(hex: "#8B5CF6"))
                                    .frame(
                                        width: geo.size.width * CGFloat(usage.outputPercent) * CGFloat(overallPercent),
                                        height: 10
                                    )
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .animation(Theme.Animation.spring, value: overallPercent)
                        }
                    }
                    .frame(height: 10)
                }

                // Token breakdown
                HStack(spacing: Theme.Spacing.md) {
                    TokenBreakdownItem(
                        color: Color(hex: "#3B82F6"),
                        label: "Input",
                        value: usage.inputTokens.tokenFormatted
                    )
                    TokenBreakdownItem(
                        color: Color(hex: "#8B5CF6"),
                        label: "Output",
                        value: usage.outputTokens.tokenFormatted
                    )
                    TokenBreakdownItem(
                        color: Color(hex: "#10B981"),
                        label: "Cached",
                        value: usage.cachedInputTokens.tokenFormatted
                    )
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Est. cost")
                            .font(Theme.Typography.caption())
                            .foregroundStyle(Theme.Colors.textSecondary)
                        Text(String(format: "$%.4f", usage.estimatedCost))
                            .font(Theme.Typography.caption(.medium))
                            .foregroundStyle(Theme.Colors.textPrimary)
                    }
                }

                if overallPercent > 0.8 {
                    warningBanner
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: overallPercent > 0.8)
        }
    }

    private var compactBar: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Today")
                    .font(Theme.Typography.caption())
                    .foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
                Text("\(usage.totalTokens.tokenFormatted)/\(plan.tokenLimit.tokenFormatted)")
                    .font(Theme.Typography.caption(.medium))
                    .foregroundStyle(barColor)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1)).frame(height: 5)
                    Capsule()
                        .fill(barGradient)
                        .frame(width: geo.size.width * overallPercent, height: 5)
                        .animation(Theme.Animation.smooth, value: overallPercent)
                }
            }
            .frame(height: 5)
        }
        .padding(.horizontal, Theme.Spacing.md)
    }

    private var barColor: Color {
        if overallPercent > 0.9 { return Theme.Colors.error }
        if overallPercent > 0.7 { return Theme.Colors.warning }
        return Theme.Colors.success
    }

    private var barGradient: LinearGradient {
        LinearGradient(
            colors: overallPercent > 0.9
                ? [Theme.Colors.error, Theme.Colors.error.opacity(0.7)]
                : overallPercent > 0.7
                    ? [Theme.Colors.warning, Color(hex: "#F59E0B")]
                    : [Color(hex: "#3B82F6"), Color(hex: "#8B5CF6")],
            startPoint: .leading, endPoint: .trailing
        )
    }

    private var warningBanner: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: overallPercent >= 1.0 ? "exclamationmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 14))
            Text(overallPercent >= 1.0
                ? "Daily limit reached. \(usage.timeUntilReset) or upgrade for more."
                : "Approaching today's limit — \(usage.remainingTokens(limit: plan.tokenLimit).tokenFormatted) tokens left.")
                .font(Theme.Typography.footnote())
        }
        .foregroundStyle(overallPercent >= 1.0 ? Theme.Colors.error : Theme.Colors.warning)
        .padding(Theme.Spacing.sm)
        .background(
            (overallPercent >= 1.0 ? Theme.Colors.error : Theme.Colors.warning).opacity(0.12)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct TokenBreakdownItem: View {
    let color: Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(Theme.Typography.caption())
                    .foregroundStyle(Theme.Colors.textSecondary)
                Text(value)
                    .font(Theme.Typography.caption(.semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
        }
    }
}
