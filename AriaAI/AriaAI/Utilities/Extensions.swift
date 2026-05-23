import SwiftUI
import UIKit

// MARK: - Color from hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        let scanner = Scanner(string: hex.hasPrefix("#") ? String(hex.dropFirst()) : hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >>  8) & 0xFF) / 255
        let b = Double( rgb        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Glass card modifier
struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat
    var padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Material.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(Theme.Glass.borderOpacity),
                                        .white.opacity(0.04)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
            }
            .shadow(color: .black.opacity(Theme.Glass.shadowOpacity), radius: 12, x: 0, y: 6)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = Theme.Glass.cornerRadius, padding: CGFloat = Theme.Spacing.md) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, padding: padding))
    }

    func primaryGradientText() -> some View {
        self.overlay(Theme.Colors.gradientPrimary).mask(self)
    }

    func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) -> some View {
        self.simultaneousGesture(TapGesture().onEnded {
            let generator = UIImpactFeedbackGenerator(style: style)
            generator.impactOccurred()
        })
    }

    func conditionalModifier<M: ViewModifier>(_ condition: Bool, modifier: M) -> some View {
        Group {
            if condition { self.modifier(modifier) } else { self }
        }
    }
}

// MARK: - Date helpers
extension Date {
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    var shortTimeString: String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: self)
    }

    var emailDateString: String {
        let cal = Calendar.current
        if cal.isDateInToday(self) { return shortTimeString }
        if cal.isDateInYesterday(self) { return "Yesterday" }
        let f = DateFormatter()
        f.dateFormat = cal.component(.year, from: self) == cal.component(.year, from: Date())
            ? "MMM d" : "MMM d, yyyy"
        return f.string(from: self)
    }
}

// MARK: - String helpers
extension String {
    var initials: String {
        let words = components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        if words.count >= 2 {
            return "\(words[0].prefix(1))\(words[1].prefix(1))".uppercased()
        }
        return prefix(2).uppercased()
    }

    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

// MARK: - Int formatting
extension Int {
    var tokenFormatted: String {
        if self >= 1_000_000 {
            return String(format: "%.1fM", Double(self) / 1_000_000)
        } else if self >= 1_000 {
            return String(format: "%.1fK", Double(self) / 1_000)
        }
        return "\(self)"
    }
}

// MARK: - UIImage compression
extension UIImage {
    func jpegDataCapped(maxBytes: Int = 1_048_576) -> Data? {
        var quality: CGFloat = 0.85
        while quality > 0.1 {
            if let data = jpegData(compressionQuality: quality), data.count <= maxBytes {
                return data
            }
            quality -= 0.15
        }
        return jpegData(compressionQuality: 0.1)
    }

    func base64EncodedString(maxBytes: Int = 1_048_576) -> String? {
        jpegDataCapped(maxBytes: maxBytes)?.base64EncodedString()
    }
}

// MARK: - Shimmer effect
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        .clear,
                        .white.opacity(0.15),
                        .clear
                    ],
                    startPoint: .init(x: phase - 0.3, y: 0),
                    endPoint: .init(x: phase + 0.3, y: 0)
                )
            )
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1.3
                }
            }
    }
}

extension View {
    func shimmer() -> some View { modifier(ShimmerModifier()) }
}
