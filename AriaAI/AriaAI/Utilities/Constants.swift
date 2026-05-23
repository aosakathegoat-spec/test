import Foundation

enum Constants {
    enum API {
        static let messagesURL = "https://api.anthropic.com/v1/messages"
        static let model = "claude-haiku-4-5"
        static let version = "2023-06-01"
        static let betaHeaders = "prompt-caching-2024-07-31"
        static let maxTokens = 1024
    }

    enum Products {
        static let coreMonthly  = "com.aria.assistant.core.monthly"
        static let proMonthly   = "com.aria.assistant.pro.monthly"
        static let ultraMonthly = "com.aria.assistant.ultra.monthly"

    }

    // Daily token limits — reset every day at 8:00 AM PST
    // Derived from profit targets at 100% worst-case utilisation (every user maxes out daily)
    // Effective cost rate: $1.65/MTok of daily-limit tokens (Haiku 4.5, 9-msg history window)
    enum TokenLimits {
        static let free:  Int =   3_000   // $0        — loss leader  (~$0.15/mo worst-case)
        static let core:  Int = 140_000   // $19.99/mo — $7.06 profit ($6.93/mo API at 100% util)
        static let pro:   Int = 360_000   // $39.99/mo — $10.17 profit ($17.82/mo API at 100% util)
        static let ultra: Int = 765_000   // $89.99/mo — $25.12 profit ($37.87/mo API at 100% util)
    }

    enum Chat {
        static let memoryWindow = 9  // messages of history sent to the API
    }

    enum ResetSchedule {
        static let hour:     Int    = 8      // 8:00 AM
        static let timezone: String = "America/Los_Angeles"  // PST/PDT
    }

    // Haiku 4.5 pricing: input $1.00/MTok, output $5.00/MTok, cached read $0.10/MTok
    enum TokenCost {
        static let inputPerToken:  Double = 0.000_001_0
        static let outputPerToken: Double = 0.000_005_0
        static let cachedPerToken: Double = 0.000_000_1
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
        static let gmailEmail      = "gmail_email"
        static let userName        = "user_name"
        static let chatSessions    = "chat_sessions"
        static let currentSession  = "current_chat_session"
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
        • Sending SMS messages to contacts via the user's phone

        SMS instructions: When the user asks to send a text or SMS, use get_contacts to look up the recipient's phone number, then call send_sms with the number and message. If you notice from email context that an SMS follow-up would help (e.g. an urgent thread, a meeting reminder), proactively offer to send one and ask the user first. Never send an SMS without the user's confirmation — the send_sms tool will show them a confirmation dialog automatically.

        Always be concise yet thorough. Match the user's tone—professional when needed, casual when appropriate. When helping with emails, be direct and provide ready-to-use drafts. You have access to the user's inbox context when provided.
        """
    }

    enum SMS {
        static let tools: [[String: Any]] = [
            [
                "name": "get_contacts",
                "description": "Search the user's phone contacts by name to find a phone number. Only call this when you need a phone number to send an SMS.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "search": [
                            "type": "string",
                            "description": "Name or partial name to search for"
                        ]
                    ],
                    "required": ["search"]
                ] as [String: Any]
            ],
            [
                "name": "send_sms",
                "description": "Request to send an SMS. The user will see a confirmation dialog before it is sent. Use get_contacts first if you need the phone number.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "phone_number": [
                            "type": "string",
                            "description": "The recipient's phone number"
                        ],
                        "contact_name": [
                            "type": "string",
                            "description": "The recipient's display name (for the confirmation dialog)"
                        ],
                        "message": [
                            "type": "string",
                            "description": "The SMS message text"
                        ]
                    ],
                    "required": ["phone_number", "message"]
                ] as [String: Any]
            ]
        ]
    }
}
