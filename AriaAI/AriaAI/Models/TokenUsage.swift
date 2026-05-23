import Foundation

struct TokenUsage: Codable {
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var cachedInputTokens: Int = 0
    // The next 8:00 AM PST after the current window started
    var nextResetDate: Date = TokenUsage.nextDailyReset()

    var totalTokens: Int { inputTokens + outputTokens }
    var allTokensIncludingCached: Int { inputTokens + outputTokens + cachedInputTokens }

    var estimatedCost: Double {
        Double(inputTokens) * Constants.TokenCost.inputPerToken +
        Double(outputTokens) * Constants.TokenCost.outputPerToken +
        Double(cachedInputTokens) * Constants.TokenCost.cachedPerToken
    }

    mutating func add(input: Int, output: Int, cached: Int = 0) {
        inputTokens       += input
        outputTokens      += output
        cachedInputTokens += cached
    }

    // Call on every load and before every usage check
    mutating func resetIfNeeded() {
        guard Date() >= nextResetDate else { return }
        inputTokens       = 0
        outputTokens      = 0
        cachedInputTokens = 0
        nextResetDate     = TokenUsage.nextDailyReset()
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

    // Returns the next 8:00 AM in America/Los_Angeles (PST/PDT)
    static func nextDailyReset() -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: Constants.ResetSchedule.timezone) ?? .current
        let now = Date()
        var components = cal.dateComponents([.year, .month, .day], from: now)
        components.hour   = Constants.ResetSchedule.hour
        components.minute = 0
        components.second = 0
        let todayReset = cal.date(from: components)!
        // If we're already past 8 AM today, the next reset is tomorrow 8 AM
        return now < todayReset ? todayReset : cal.date(byAdding: .day, value: 1, to: todayReset)!
    }

    var timeUntilReset: String {
        let interval = nextResetDate.timeIntervalSinceNow
        guard interval > 0 else { return "Resetting…" }
        let hours   = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 { return "Resets in \(hours)h \(minutes)m" }
        return "Resets in \(minutes)m"
    }
}

extension TokenUsage {
    static func load() -> TokenUsage {
        let defaults = UserDefaults.standard
        var usage = TokenUsage()
        usage.inputTokens       = defaults.integer(forKey: Constants.UserDefaultsKeys.inputTokens)
        usage.outputTokens      = defaults.integer(forKey: Constants.UserDefaultsKeys.outputTokens)
        usage.cachedInputTokens = defaults.integer(forKey: Constants.UserDefaultsKeys.cachedTokens)
        usage.nextResetDate = (defaults.object(forKey: Constants.UserDefaultsKeys.resetDate) as? Date)
            ?? TokenUsage.nextDailyReset()
        usage.resetIfNeeded()
        return usage
    }

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(inputTokens,       forKey: Constants.UserDefaultsKeys.inputTokens)
        defaults.set(outputTokens,      forKey: Constants.UserDefaultsKeys.outputTokens)
        defaults.set(cachedInputTokens, forKey: Constants.UserDefaultsKeys.cachedTokens)
        defaults.set(nextResetDate,     forKey: Constants.UserDefaultsKeys.resetDate)
    }
}
