import Foundation

struct TokenUsage: Codable {
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var cachedInputTokens: Int = 0
    var resetDate: Date = Date()

    var totalTokens: Int { inputTokens + outputTokens }
    var allTokensIncludingCached: Int { inputTokens + outputTokens + cachedInputTokens }

    var estimatedCost: Double {
        Double(inputTokens) * Constants.TokenCost.inputPerToken +
        Double(outputTokens) * Constants.TokenCost.outputPerToken +
        Double(cachedInputTokens) * Constants.TokenCost.cachedPerToken
    }

    mutating func add(input: Int, output: Int, cached: Int = 0) {
        inputTokens  += input
        outputTokens += output
        cachedInputTokens += cached
    }

    mutating func resetIfNewMonth() {
        if !resetDate.isSameMonth {
            inputTokens       = 0
            outputTokens      = 0
            cachedInputTokens = 0
            resetDate         = Date()
        }
    }

    func usagePercent(limit: Int) -> Double {
        guard limit > 0 else { return 0 }
        return min(1.0, Double(totalTokens) / Double(limit))
    }

    func remainingTokens(limit: Int) -> Int {
        max(0, limit - totalTokens)
    }

    var inputPercent: Double {
        guard totalTokens > 0 else { return 0 }
        return Double(inputTokens) / Double(totalTokens)
    }

    var outputPercent: Double {
        guard totalTokens > 0 else { return 0 }
        return Double(outputTokens) / Double(totalTokens)
    }
}

extension TokenUsage {
    static func load() -> TokenUsage {
        let defaults = UserDefaults.standard
        var usage = TokenUsage()
        usage.inputTokens       = defaults.integer(forKey: Constants.UserDefaultsKeys.inputTokens)
        usage.outputTokens      = defaults.integer(forKey: Constants.UserDefaultsKeys.outputTokens)
        usage.cachedInputTokens = defaults.integer(forKey: Constants.UserDefaultsKeys.cachedTokens)
        usage.resetDate = (defaults.object(forKey: Constants.UserDefaultsKeys.resetDate) as? Date) ?? Date()
        usage.resetIfNewMonth()
        return usage
    }

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(inputTokens,       forKey: Constants.UserDefaultsKeys.inputTokens)
        defaults.set(outputTokens,      forKey: Constants.UserDefaultsKeys.outputTokens)
        defaults.set(cachedInputTokens, forKey: Constants.UserDefaultsKeys.cachedTokens)
        defaults.set(resetDate,         forKey: Constants.UserDefaultsKeys.resetDate)
    }
}
