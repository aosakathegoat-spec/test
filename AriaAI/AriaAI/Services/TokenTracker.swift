import Foundation
import Combine

@MainActor
class TokenTracker: ObservableObject {
    static let shared = TokenTracker()

    @Published var usage: TokenUsage = .load()
    @Published var plan: SubscriptionPlan = .free

    private init() {
        let planRaw = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.plan) ?? "free"
        plan = SubscriptionPlan(rawValue: planRaw) ?? .free
    }

    var tokenLimit: Int { plan.tokenLimit }

    var usagePercent: Double { usage.usagePercent(limit: tokenLimit) }

    var isOverLimit: Bool { usage.totalTokens >= tokenLimit }

    var remainingTokens: Int { usage.remainingTokens(limit: tokenLimit) }

    func record(input: Int, output: Int, cached: Int = 0) {
        usage.resetIfNeeded()   // clear stale day before writing
        usage.add(input: input, output: output, cached: cached)
        usage.save()
    }

    func refreshReset() {
        usage.resetIfNeeded()
    }

    func updatePlan(_ newPlan: SubscriptionPlan) {
        plan = newPlan
        UserDefaults.standard.set(newPlan.rawValue, forKey: Constants.UserDefaultsKeys.plan)
    }

    func canSendRequest(estimatedTokens: Int = 500) -> Bool {
        !isOverLimit && (usage.totalTokens + estimatedTokens) <= tokenLimit
    }
}
