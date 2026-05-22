import SwiftUI

struct LiquidGlassBackground: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            // Base deep background
            Color(hex: "#060A18")
                .ignoresSafeArea()

            // Primary ambient orb - top left
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "#3B6EF0").opacity(0.35), .clear],
                        center: .center, startRadius: 0, endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(x: animate ? -80 : -120, y: animate ? -180 : -220)
                .blur(radius: 60)
                .animation(
                    .easeInOut(duration: 8).repeatForever(autoreverses: true),
                    value: animate
                )

            // Secondary orb - bottom right
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "#8B4FD8").opacity(0.3), .clear],
                        center: .center, startRadius: 0, endRadius: 180
                    )
                )
                .frame(width: 360, height: 360)
                .offset(x: animate ? 140 : 100, y: animate ? 260 : 220)
                .blur(radius: 70)
                .animation(
                    .easeInOut(duration: 10).repeatForever(autoreverses: true),
                    value: animate
                )

            // Accent orb - center
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "#0EA5E9").opacity(0.15), .clear],
                        center: .center, startRadius: 0, endRadius: 150
                    )
                )
                .frame(width: 300, height: 300)
                .offset(x: animate ? 20 : -30, y: animate ? 60 : 100)
                .blur(radius: 80)
                .animation(
                    .easeInOut(duration: 12).repeatForever(autoreverses: true),
                    value: animate
                )

            // Noise texture overlay for glass feel
            Rectangle()
                .fill(Color.white.opacity(0.015))
                .ignoresSafeArea()
                .blendMode(.overlay)
        }
        .onAppear { animate = true }
    }
}

// Compact glass background for sheets
struct SheetGlassBackground: View {
    var body: some View {
        ZStack {
            Color(hex: "#0A0F1E").ignoresSafeArea()
            LinearGradient(
                colors: [
                    Color(hex: "#1A1040").opacity(0.6),
                    Color(hex: "#0A1528").opacity(0.4)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
}

// Reusable glass card with gradient border
struct AriaGlassCard<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat = Theme.Glass.cornerRadius
    var padding: CGFloat = Theme.Spacing.md
    var gradientBorder: Bool = true

    init(
        cornerRadius: CGFloat = Theme.Glass.cornerRadius,
        padding: CGFloat = Theme.Spacing.md,
        gradientBorder: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.gradientBorder = gradientBorder
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Material.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            }
            .overlay {
                if gradientBorder {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.22), .white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            }
            .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 8)
    }
}

// Pill badge
struct GlassBadge: View {
    let text: String
    var color: Color = Theme.Colors.primary

    var body: some View {
        Text(text)
            .font(Theme.Typography.caption(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(color.opacity(0.3), lineWidth: 1))
    }
}

// Gradient button
struct GradientButton: View {
    let title: String
    let gradient: LinearGradient
    let action: () -> Void
    var isLoading = false
    var fullWidth = true

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.xs) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(0.8)
                } else {
                    Text(title)
                        .font(Theme.Typography.body(.semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(height: Theme.Size.buttonHeight)
            .padding(.horizontal, fullWidth ? 0 : Theme.Spacing.lg)
        }
        .background(gradient)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadiusSm, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        .disabled(isLoading)
    }
}
