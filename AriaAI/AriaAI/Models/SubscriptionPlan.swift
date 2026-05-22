import Foundation
import SwiftUI

enum SubscriptionPlan: String, Codable, CaseIterable {
    case free, core, pro, ultra

    var displayName: String {
        switch self {
        case .free:  return "Free"
        case .core:  return "Core"
        case .pro:   return "Pro"
        case .ultra: return "Ultra"
        }
    }

    var tagline: String {
        switch self {
        case .free:  return "Get started"
        case .core:  return "For daily use"
        case .pro:   return "Power users"
        case .ultra: return "Maximum power"
        }
    }

    var monthlyPrice: Double {
        switch self {
        case .free:  return 0
        case .core:  return 2.99
        case .pro:   return 9.99
        case .ultra: return 24.99
        }
    }

    var priceDisplay: String {
        switch self {
        case .free:  return "Free"
        case .core:  return "$2.99/mo"
        case .pro:   return "$9.99/mo"
        case .ultra: return "$24.99/mo"
        }
    }

    var tokenLimit: Int {
        switch self {
        case .free:  return Constants.TokenLimits.free
        case .core:  return Constants.TokenLimits.core
        case .pro:   return Constants.TokenLimits.pro
        case .ultra: return Constants.TokenLimits.ultra
        }
    }

    var tokenLimitDisplay: String {
        switch self {
        case .free:  return "50K tokens/mo"
        case .core:  return "500K tokens/mo"
        case .pro:   return "2M tokens/mo"
        case .ultra: return "8M tokens/mo"
        }
    }

    var productID: String? {
        switch self {
        case .free:  return nil
        case .core:  return Constants.Products.coreMonthly
        case .pro:   return Constants.Products.proMonthly
        case .ultra: return Constants.Products.ultraMonthly
        }
    }

    var features: [PlanFeature] {
        switch self {
        case .free:
            return [
                .init(icon: "message", title: "AI Chat",         included: true),
                .init(icon: "envelope", title: "Send Email",      included: true),
                .init(icon: "tray.full", title: "Read Inbox",     included: false),
                .init(icon: "speaker.wave.2", title: "Voice Mode", included: false),
                .init(icon: "photo", title: "Image Analysis",     included: false),
                .init(icon: "sun.horizon", title: "Morning Briefing", included: false),
                .init(icon: "arrow.clockwise", title: "50K tokens/mo", included: true),
            ]
        case .core:
            return [
                .init(icon: "message", title: "AI Chat",         included: true),
                .init(icon: "envelope", title: "Send Email",      included: true),
                .init(icon: "tray.full", title: "Read Inbox",     included: true),
                .init(icon: "speaker.wave.2", title: "Voice Mode", included: true),
                .init(icon: "photo", title: "Image Analysis",     included: false),
                .init(icon: "sun.horizon", title: "Morning Briefing", included: false),
                .init(icon: "arrow.clockwise", title: "500K tokens/mo", included: true),
            ]
        case .pro:
            return [
                .init(icon: "message", title: "AI Chat",         included: true),
                .init(icon: "envelope", title: "Send Email",      included: true),
                .init(icon: "tray.full", title: "Read Inbox",     included: true),
                .init(icon: "speaker.wave.2", title: "Voice Mode", included: true),
                .init(icon: "photo", title: "Image Analysis",     included: true),
                .init(icon: "sun.horizon", title: "Morning Briefing", included: true),
                .init(icon: "arrow.clockwise", title: "2M tokens/mo", included: true),
            ]
        case .ultra:
            return [
                .init(icon: "message", title: "AI Chat",         included: true),
                .init(icon: "envelope", title: "Send Email",      included: true),
                .init(icon: "tray.full", title: "Read Inbox",     included: true),
                .init(icon: "speaker.wave.2", title: "Voice Mode", included: true),
                .init(icon: "photo", title: "Image Analysis",     included: true),
                .init(icon: "sun.horizon", title: "Morning Briefing", included: true),
                .init(icon: "arrow.clockwise", title: "8M tokens/mo",  included: true),
            ]
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .free:  return [Color(hex: "#4A5568"), Color(hex: "#2D3748")]
        case .core:  return [Color(hex: "#3B82F6"), Color(hex: "#2563EB")]
        case .pro:   return [Color(hex: "#8B5CF6"), Color(hex: "#6D28D9")]
        case .ultra: return [Color(hex: "#F59E0B"), Color(hex: "#D97706")]
        }
    }

    var accentColor: Color {
        switch self {
        case .free:  return Color(hex: "#718096")
        case .core:  return Color(hex: "#60A5FA")
        case .pro:   return Color(hex: "#A78BFA")
        case .ultra: return Color(hex: "#FCD34D")
        }
    }

    var isPopular: Bool { self == .pro }

    var canReadEmails: Bool     { self != .free }
    var canUseVoice: Bool       { self != .free }
    var canAnalyzeImages: Bool  { self == .pro || self == .ultra }
    var hasMorningBriefing: Bool { self == .pro || self == .ultra }
}

struct PlanFeature: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let included: Bool
}
