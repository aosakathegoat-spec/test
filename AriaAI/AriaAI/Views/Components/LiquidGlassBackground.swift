import SwiftUI

// MARK: - Main app background
struct LiquidGlassBackground: View {
    @State private var phase = false

    var body: some View {
        ZStack {
            // Base — near-black midnight
            Color(hex: "#07091A").ignoresSafeArea()

            // Top-left cool orb
            ellipseOrb(
                color: Color(hex: "#2563EB"),
                opacity: phase ? 0.22 : 0.14,
                width: 380, height: 320,
                offset: CGSize(width: -100, height: -240),
                blur: 90,
                duration: 9
            )

            // Bottom-right warm-purple orb
            ellipseOrb(
                color: Color(hex: "#7C3AED"),
                opacity: phase ? 0.18 : 0.11,
                width: 340, height: 300,
                offset: CGSize(width: 150, height: 280),
                blur: 80,
                duration: 11
            )

            // Centre accent — subtle cyan
            ellipseOrb(
                color: Color(hex: "#0891B2"),
                opacity: phase ? 0.10 : 0.06,
                width: 260, height: 220,
                offset: CGSize(width: 30, height: 40),
                blur: 100,
                duration: 14
            )

            // Frutiger Aero — subtle specular grain
            Rectangle()
                .fill(Color.white.opacity(0.012))
                .ignoresSafeArea()
                .blendMode(.overlay)
        }
        .onAppear { withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) { phase = true } }
    }

    private func ellipseOrb(
        color: Color, opacity: Double,
        width: CGFloat, height: CGFloat,
        offset: CGSize, blur: CGFloat, duration: Double
    ) -> some View {
        Ellipse()
            .fill(color.opacity(opacity))
            .frame(width: width, height: height)
            .offset(offset)
            .blur(radius: blur)
            .animation(.easeInOut(duration: duration).repeatForever(autoreverses: true), value: phase)
    }
}

// MARK: - Sheet background
struct SheetGlassBackground: View {
    var body: some View {
        ZStack {
            Color(hex: "#080C1E").ignoresSafeArea()
            LinearGradient(
                colors: [Color(hex: "#1A1040").opacity(0.5), .clear],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Reusable glass card
struct AriaGlassCard<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat   = Theme.Glass.cornerRadius
    var padding: CGFloat        = Theme.Spacing.md
    var gradientBorder: Bool    = true
    var glowColor: Color?       = nil

    init(
        cornerRadius: CGFloat = Theme.Glass.cornerRadius,
        padding: CGFloat = Theme.Spacing.md,
        gradientBorder: Bool = true,
        glowColor: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius   = cornerRadius
        self.padding        = padding
        self.gradientBorder = gradientBorder
        self.glowColor      = glowColor
        self.content        = content()
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
                                colors: [.white.opacity(0.20), .white.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            }
            .shadow(
                color: glowColor?.opacity(0.18) ?? .black.opacity(0.22),
                radius: 14, x: 0, y: 7
            )
    }
}

// MARK: - Pill badge
struct GlassBadge: View {
    let text: String
    var color: Color = Theme.Colors.primary

    var body: some View {
        Text(text)
            .font(Theme.Typography.caption(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.14))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(color.opacity(0.28), lineWidth: 1))
    }
}

// MARK: - Gradient CTA button
struct GradientButton: View {
    let title: String
    let gradient: LinearGradient
    let action: () -> Void
    var isLoading = false
    var fullWidth = true

    var body: some View {
        Button(action: { UIImpactFeedbackGenerator(style: .medium).impactOccurred(); action() }) {
            HStack(spacing: Theme.Spacing.xs) {
                if isLoading {
                    ProgressView().progressViewStyle(.circular).tint(.white).scaleEffect(0.8)
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
        .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
        .disabled(isLoading)
    }
}
