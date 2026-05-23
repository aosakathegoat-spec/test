import SwiftUI

struct AgeEntryView: View {
    @EnvironmentObject private var auth: AuthService
    @State private var appeared = false
    @State private var cardOffsets: [CGFloat] = [40, 40, 40]
    @State private var cardOpacities: [Double] = [0, 0, 0]

    private let months = ["January","February","March","April","May","June",
                          "July","August","September","October","November","December"]
    private var maxYear:  Int { Calendar.current.component(.year, from: Date()) - 13 }
    private var minYear:  Int { maxYear - 87 }

    private var maxDay: Int {
        let comps = DateComponents(year: auth.birthYear, month: auth.birthMonth)
        return Calendar.current.range(of: .day, in: .month, for: Calendar.current.date(from: comps) ?? Date())?.count ?? 31
    }

    var body: some View {
        ZStack {
            LiquidGlassBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 60)

                    // Header
                    VStack(spacing: 10) {
                        Text("When were you born?")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .multilineTextAlignment(.center)
                        Text("Kept private — used to personalize your experience.")
                            .font(Theme.Typography.callout())
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .opacity(cardOpacities[0])
                    .padding(.horizontal, Theme.Spacing.xl)

                    Spacer().frame(height: 40)

                    // Month slider
                    sliderCard(
                        label: "Month",
                        valueLabel: months[auth.birthMonth - 1],
                        sliderValue: Binding(
                            get:  { Double(auth.birthMonth) },
                            set:  { auth.birthMonth = Int($0.rounded()) }
                        ),
                        range: 1...12,
                        accentColor: Color(hex: "#4F8EF7"),
                        index: 0
                    )
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.bottom, Theme.Spacing.sm)

                    // Day slider
                    sliderCard(
                        label: "Day",
                        valueLabel: "\(min(auth.birthDay, maxDay))",
                        sliderValue: Binding(
                            get:  { Double(min(auth.birthDay, maxDay)) },
                            set:  { auth.birthDay = Int($0.rounded()) }
                        ),
                        range: 1...Double(maxDay),
                        accentColor: Color(hex: "#8B5CF6"),
                        index: 1
                    )
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.bottom, Theme.Spacing.sm)

                    // Year slider
                    sliderCard(
                        label: "Year",
                        valueLabel: "\(auth.birthYear)",
                        sliderValue: Binding(
                            get:  { Double(auth.birthYear) },
                            set:  { auth.birthYear = Int($0.rounded()) }
                        ),
                        range: Double(minYear)...Double(maxYear),
                        accentColor: Color(hex: "#10B981"),
                        index: 2
                    )
                    .padding(.horizontal, Theme.Spacing.md)

                    Spacer().frame(height: 28)

                    // Summary
                    HStack(spacing: 8) {
                        Image(systemName: "birthday.cake")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.Colors.textSecondary)
                        Text(auth.birthDateDisplay)
                            .font(Theme.Typography.callout(.medium))
                            .foregroundStyle(Theme.Colors.textSecondary)
                        Text("· \(auth.age) years old")
                            .font(Theme.Typography.callout())
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 20)
                    .background(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeInOut(duration: 0.3).delay(0.6), value: appeared)

                    Spacer().frame(height: 32)

                    GradientButton(
                        title: "Continue",
                        gradient: Theme.Colors.gradientPrimary
                    ) {
                        withAnimation(Theme.Animation.spring) {
                            auth.saveAge()
                        }
                    }
                    .padding(.horizontal, 48)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.3).delay(0.65), value: appeared)

                    Spacer().frame(height: 60)
                }
            }
        }
        .onAppear { animateIn() }
    }

    // MARK: - Slider card
    private func sliderCard(
        label: String,
        valueLabel: String,
        sliderValue: Binding<Double>,
        range: ClosedRange<Double>,
        accentColor: Color,
        index: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(label)
                    .font(Theme.Typography.footnote(.semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                Spacer()
                Text(valueLabel)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(accentColor)
                    .contentTransition(.numericText())
                    .animation(Theme.Animation.snappy, value: valueLabel)
            }

            // Custom styled slider
            Slider(value: sliderValue, in: range, step: 1)
                .tint(accentColor)
                .padding(.vertical, 2)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.md)
        .background(.ultraThinMaterial)
        .environment(\.colorScheme, .dark)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [accentColor.opacity(0.3), .white.opacity(0.06)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: accentColor.opacity(0.12), radius: 12, x: 0, y: 6)
        .offset(y: cardOffsets[safe: index] ?? 0)
        .opacity(cardOpacities[safe: index] ?? 0)
    }

    private func animateIn() {
        appeared = true
        for i in 0..<3 {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.15 + Double(i) * 0.1)) {
                cardOffsets[i]   = 0
                cardOpacities[i] = 1
            }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0 && index < count else { return nil }
        return self[index]
    }
}
