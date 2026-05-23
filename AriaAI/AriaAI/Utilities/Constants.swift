import Foundation

enum Constants {
    enum API {
        static var key: String {
            UserDefaults.standard.string(forKey: UserDefaultsKeys.apiKey) ?? ""
        }
        static let messagesURL = "https://api.anthropic.com/v1/messages"
        static let model = "claude-haiku-4-5-20251001"
        static let version = "2023-06-01"
        static let betaHeaders = "prompt-caching-2024-07-31"
        static let maxTokens = 4096
    }

    enum Products {
        static let coreMonthly  = "com.aria.assistant.core.monthly"
        static let proMonthly   = "com.aria.assistant.pro.monthly"
        static let ultraMonthly = "com.aria.assistant.ultra.monthly"

        // Pricing — after Apple 30% cut + Haiku API costs, margins are:
        //   Core  $9.99/mo:  ~$5.37 profit  (60K/day, API ~$1.62/mo)
        //   Pro  $22.99/mo: ~$10.69 profit (200K/day, API ~$5.40/mo)
        //   Ultra $44.99/mo: ~$12.59 profit (700K/day, API ~$18.90/mo)
        static let corePriceDisplay  = "$9.99/mo"
        static let proPriceDisplay   = "$22.99/mo"
        static let ultraPriceDisplay = "$44.99/mo"
    }

    // Daily token limits — reset every day at 8:00 AM PST
    enum TokenLimits {
        static let free:  Int =   3_000   // $0       — loss leader
        static let core:  Int =  60_000   // $9.99/mo — ~$5.37 net profit
        static let pro:   Int = 200_000   // $22.99/mo — ~$10.69 net profit
        static let ultra: Int = 700_000   // $44.99/mo — ~$12.59 net profit
    }

    enum Chat {
        static let memoryWindow = 9  // messages of history sent to the API
    }

    enum ResetSchedule {
        static let hour:     Int    = 8      // 8:00 AM
        static let timezone: String = "America/Los_Angeles"  // PST/PDT
    }

    // Haiku pricing: input $0.80/MTok, output $1.00/MTok, cached $0.08/MTok
    enum TokenCost {
        static let inputPerToken:  Double = 0.000_000_8
        static let outputPerToken: Double = 0.000_001_0
        static let cachedPerToken: Double = 0.000_000_08
    }

    enum UserDefaultsKeys {
        static let apiKey          = "api_key"
        static let plan            = "subscription_plan"
        static let inputTokens     = "daily_input_tokens"
        static let outputTokens    = "daily_output_tokens"
        static let cachedTokens    = "daily_cached_tokens"
        static let resetDate       = "token_next_reset_date"
        static let onboardingDone  = "onboarding_complete"
        static let morningBriefing = "morning_briefing_enabled"
        static let briefingHour    = "briefing_hour"
        static let briefingMinute  = "briefing_minute"
        static let selectedVoice   = "selected_voice"
        static let gmailToken      = "gmail_access_token"
        static let gmailRefresh    = "gmail_refresh_token"
        static let gmailEmail      = "gmail_email"
        static let userName        = "user_name"
    }

    enum Gmail {
        static let clientID    = "YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com"
        static let redirectURI = "com.aria.assistant:/oauth2callback"
        static let authURL     = "https://accounts.google.com/o/oauth2/v2/auth"
        static let tokenURL    = "https://oauth2.googleapis.com/token"
        static let scope       = "https://www.googleapis.com/auth/gmail.readonly https://www.googleapis.com/auth/gmail.send https://www.googleapis.com/auth/gmail.compose"
        static let apiBase     = "https://gmail.googleapis.com/gmail/v1/users/me"
    }

    enum SystemPrompt {
        static let aria = """
        You are Aria, an intelligent AI personal assistant. You are warm, proactive, and highly capable. Your core abilities include:
        • Natural conversation and answering questions across all domains
        • Drafting, summarizing, and analyzing emails professionally
        • Creating personalized morning briefings
        • Analyzing images, documents, and screenshots
        • Helping with tasks, planning, and decision-making

        Always be concise yet thorough. Match the user's tone—professional when needed, casual when appropriate. When helping with emails, be direct and provide ready-to-use drafts. You have access to the user's inbox context when provided.
        """
    }
}
