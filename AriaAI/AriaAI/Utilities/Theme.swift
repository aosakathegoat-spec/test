import SwiftUI

enum Theme {
    // MARK: - Colors
    enum Colors {
        static let background    = Color(hex: "#080C1A")
        static let surface       = Color(hex: "#0F1628")
        static let surfaceAlt    = Color(hex: "#141E35")
        static let primary       = Color(hex: "#4F8EF7")
        static let primaryLight  = Color(hex: "#7EB3FF")
        static let accent        = Color(hex: "#9B6DFF")
        static let accentLight   = Color(hex: "#C49EFF")
        static let success       = Color(hex: "#34D399")
        static let warning       = Color(hex: "#FBBF24")
        static let error         = Color(hex: "#F87171")
        static let textPrimary   = Color.white
        static let textSecondary = Color(hex: "#8B9AB8")
        static let textTertiary  = Color(hex: "#4A5568")
        static let separator     = Color.white.opacity(0.08)

        static let gradientPrimary = LinearGradient(
            colors: [Color(hex: "#4F8EF7"), Color(hex: "#9B6DFF")],
            startPoint: .leading, endPoint: .trailing
        )
        static let gradientAccent = LinearGradient(
            colors: [Color(hex: "#9B6DFF"), Color(hex: "#F472B6")],
            startPoint: .leading, endPoint: .trailing
        )
        static let gradientBackground = LinearGradient(
            colors: [Color(hex: "#080C1A"), Color(hex: "#0D1640"), Color(hex: "#080C1A")],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    // MARK: - Glass
    enum Glass {
        static let ultraThin  = Material.ultraThinMaterial
        static let thin       = Material.thinMaterial
        static let regular    = Material.regularMaterial
        static let borderOpacity: Double = 0.18
        static let shadowOpacity: Double = 0.25
        static let cornerRadius: CGFloat = 20
        static let cornerRadiusSm: CGFloat = 14
        static let cornerRadiusLg: CGFloat = 28
    }

    // MARK: - Typography
    enum Typography {
        static func largeTitle(_ weight: Font.Weight = .bold) -> Font {
            .system(size: 34, weight: weight, design: .rounded)
        }
        static func title(_ weight: Font.Weight = .semibold) -> Font {
            .system(size: 28, weight: weight, design: .rounded)
        }
        static func title2(_ weight: Font.Weight = .semibold) -> Font {
            .system(size: 22, weight: weight, design: .rounded)
        }
        static func title3(_ weight: Font.Weight = .medium) -> Font {
            .system(size: 20, weight: weight, design: .rounded)
        }
        static func body(_ weight: Font.Weight = .regular) -> Font {
            .system(size: 17, weight: weight, design: .default)
        }
        static func callout(_ weight: Font.Weight = .regular) -> Font {
            .system(size: 16, weight: weight, design: .default)
        }
        static func subheadline(_ weight: Font.Weight = .regular) -> Font {
            .system(size: 15, weight: weight, design: .default)
        }
        static func footnote(_ weight: Font.Weight = .regular) -> Font {
            .system(size: 13, weight: weight, design: .default)
        }
        static func caption(_ weight: Font.Weight = .regular) -> Font {
            .system(size: 12, weight: weight, design: .default)
        }
    }

    // MARK: - Spacing
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs:  CGFloat = 8
        static let sm:  CGFloat = 12
        static let md:  CGFloat = 16
        static let lg:  CGFloat = 24
        static let xl:  CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Animation
    enum Animation {
        static let spring = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.8)
        static let snappy = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.75)
        static let smooth = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let quick  = SwiftUI.Animation.easeOut(duration: 0.2)
    }

    // MARK: - Sizing
    enum Size {
        static let tabBarHeight:    CGFloat = 83
        static let navBarHeight:    CGFloat = 52
        static let buttonHeight:    CGFloat = 54
        static let buttonHeightSm:  CGFloat = 44
        static let iconSizeSm:      CGFloat = 20
        static let iconSizeMd:      CGFloat = 24
        static let iconSizeLg:      CGFloat = 32
        static let avatarSizeSm:    CGFloat = 36
        static let avatarSizeMd:    CGFloat = 48
    }
}
