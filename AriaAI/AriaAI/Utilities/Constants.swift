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
        static let chatSessions        = "chat_sessions"
        static let currentSession      = "current_chat_session"
        static let pendingSiriRequest  = "pending_siri_request"
        static let lastActiveTimestamp = "last_active_timestamp"
        static let friendsUsername     = "friends_username"
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
        • Opening apps on the user's device
        • Guiding the user to delete apps
        • Opening Screen Time settings

        SMS: When the user asks to send a text/SMS, use get_contacts to find the number, then send_sms. If you notice from email context that an SMS follow-up would help, proactively offer. Never send without confirmation — send_sms shows a dialog automatically.

        Apps: When the user asks to open an app (e.g. "open Spotify", "launch Maps"), call get_app_list first to confirm it's installed, then call open_app. If you're unsure of the exact app id, always check get_app_list first. You can also proactively offer to open a relevant app when it would help.

        Delete apps: When the user asks to delete, remove, or uninstall an app, call delete_app with the app name. iOS does not allow apps to be deleted programmatically, so you will receive step-by-step instructions to relay to the user.

        Screen Time: When the user asks to open, view, or configure Screen Time (app limits, downtime, restrictions, parental controls), call open_screen_time to open the Screen Time settings page. Then guide the user through the specific setting they want to change.

        Always be concise yet thorough. Match the user's tone. When helping with emails, provide ready-to-use drafts.
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

    enum AppLauncher {
        static let tools: [[String: Any]] = [
            [
                "name": "get_app_list",
                "description": "Get the list of apps installed on the user's device. Call this before open_app to confirm the app is available and get the correct id. Returns app name, id, and category.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "category": [
                            "type": "string",
                            "description": "Optional filter: social, communication, productivity, navigation, entertainment, finance, food, health, browser, system, or all",
                        ]
                    ],
                    "required": []
                ] as [String: Any]
            ],
            [
                "name": "open_app",
                "description": "Open an app on the user's device. Use the id from get_app_list. The app will open immediately.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "app_id": [
                            "type": "string",
                            "description": "The app id from get_app_list (e.g. 'spotify', 'maps', 'instagram')"
                        ],
                        "app_name": [
                            "type": "string",
                            "description": "The app's display name, for confirmation text"
                        ]
                    ],
                    "required": ["app_id"]
                ] as [String: Any]
            ]
        ]
    }

    enum DeviceControl {
        static let tools: [[String: Any]] = [
            [
                "name": "delete_app",
                "description": "Guide the user through deleting an installed app. iOS does not allow apps to be deleted programmatically, so this returns clear step-by-step deletion instructions the user can follow immediately.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "app_name": [
                            "type": "string",
                            "description": "The display name of the app to delete (e.g. 'Instagram', 'TikTok')"
                        ]
                    ],
                    "required": ["app_name"]
                ] as [String: Any]
            ],
            [
                "name": "open_screen_time",
                "description": "Open the Screen Time page in iOS Settings where the user can set app limits, schedule downtime, configure content & privacy restrictions, and manage communication limits.",
                "input_schema": [
                    "type": "object",
                    "properties": [:],
                    "required": []
                ] as [String: Any]
            ]
        ]
    }

    enum Tools {
        static let all: [[String: Any]] = SMS.tools + AppLauncher.tools + DeviceControl.tools
    }
}
