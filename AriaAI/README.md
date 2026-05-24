# Aria — AI Personal Assistant for iOS

A complete, production-ready iOS app powered by Claude Haiku. Built with SwiftUI, featuring a liquid glass UI, email management, voice mode, morning briefings, and subscription tiers.

---

## Quick Setup in Xcode

### Option A — XcodeGen (Recommended)
```bash
# Install XcodeGen if needed
brew install xcodegen

# Generate Xcode project
cd AriaAI
xcodegen generate

# Open in Xcode
open AriaAI.xcodeproj
```

### Option B — Manual
1. Create a new iOS App project in Xcode (SwiftUI, Swift)
2. Set Bundle ID to `com.aria.assistant`
3. Delete the generated files, then drag all folders from `AriaAI/` into the project
4. Add the entitlements file and Info.plist

---

## Configuration (Before Building)

### 1. Anthropic API Key
Users enter their key in **Settings → API Key**. The key is stored in `UserDefaults` on-device only. No server involved.

### 2. Google OAuth (Gmail)
1. Create a project at [Google Cloud Console](https://console.cloud.google.com)
2. Enable the **Gmail API**
3. Create OAuth 2.0 credentials (iOS app type)
4. Copy your `CLIENT_ID` to `Constants.Gmail.clientID` in `AriaAI/Utilities/Constants.swift`
5. Add the URL scheme `com.aria.assistant` to your Google OAuth redirect URIs

### 3. In-App Purchases (StoreKit)
Create these subscription products in [App Store Connect](https://appstoreconnect.apple.com):

| Product ID | Price | Type |
|---|---|---|
| `com.aria.assistant.core.monthly` | $2.99 | Auto-Renewable Subscription |
| `com.aria.assistant.pro.monthly` | $9.99 | Auto-Renewable Subscription |
| `com.aria.assistant.ultra.monthly` | $24.99 | Auto-Renewable Subscription |

---

## Pricing & Margin Analysis

| Plan | Price | Token Limit | API Cost (est.) | Net Margin |
|---|---|---|---|---|
| Free | $0 | 50K/mo | ~$0.05 | — |
| Core | $2.99/mo | 500K/mo | ~$0.45 | ~$1.64* |
| Pro | $9.99/mo | 2M/mo | ~$1.80 | ~$5.19* |
| Ultra | $24.99/mo | 8M/mo | ~$7.20 | ~$10.29* |

*After Apple's 30% cut. Based on Haiku pricing: $0.80/MTok input, $1.00/MTok output, $0.08/MTok cached.

---

## Features

| Feature | Free | Core | Pro | Ultra |
|---|---|---|---|---|
| AI Chat | ✓ | ✓ | ✓ | ✓ |
| Send Email | ✓ | ✓ | ✓ | ✓ |
| Read Inbox | ✗ | ✓ | ✓ | ✓ |
| Voice Mode | ✗ | ✓ | ✓ | ✓ |
| Image Analysis | ✗ | ✗ | ✓ | ✓ |
| Morning Briefing | ✗ | ✗ | ✓ | ✓ |
| Monthly Tokens | 50K | 500K | 2M | 8M |

---

## Architecture

```
AriaAI/
├── Utilities/
│   ├── Constants.swift        # API config, pricing, keys
│   ├── Theme.swift            # Colors, typography, spacing
│   └── Extensions.swift       # SwiftUI helpers, glass modifier
├── Models/
│   ├── Message.swift          # Chat messages + Anthropic API models
│   ├── Email.swift            # Email + Gmail API models
│   ├── TokenUsage.swift       # Token tracking model
│   └── SubscriptionPlan.swift # Plan enum with features + pricing
├── Services/
│   ├── AIService.swift        # Anthropic API, streaming, caching
│   ├── EmailService.swift     # Gmail OAuth + send/receive
│   ├── VoiceService.swift     # TTS + STT (AVFoundation + SFSpeech)
│   ├── TokenTracker.swift     # Usage tracking + limits
│   ├── PurchaseService.swift  # StoreKit 2 subscriptions
│   └── MorningBriefingService.swift # Daily briefing generation
├── ViewModels/
│   ├── AppState.swift         # Global state, navigation
│   ├── ChatViewModel.swift    # Chat session management
│   ├── InboxViewModel.swift   # Email list + compose
│   └── SettingsViewModel.swift
└── Views/
    ├── Components/            # Reusable glass UI components
    ├── Chat/ChatView.swift    # Main chat interface
    ├── Inbox/                 # Email views
    ├── Morning/               # Morning briefing
    ├── Settings/SettingsView.swift
    ├── Subscription/PricingView.swift
    └── Onboarding/OnboardingView.swift
```

---

## Key Technical Details

### Claude Haiku Integration
- Model: `claude-haiku-4-5-20251001`
- Streaming SSE responses via `URLSession.bytes`
- **System prompt caching** with `"cache_control": {"type": "ephemeral"}` header — saves ~90% on repeated system prompt tokens
- Vision support: base64-encoded images up to 1MB

### Token Tracking
Tracks separately:
- **Input tokens** — prompt tokens charged at $0.80/MTok
- **Output tokens** — completion tokens charged at $1.00/MTok  
- **Cached input tokens** — cached prompt reads at $0.08/MTok (10x savings)
- **Total** = input + output (used for plan limit enforcement)

### Voice
- TTS: `AVSpeechSynthesizer` with premium/enhanced Siri voices
- STT: `SFSpeechRecognizer` + `AVAudioEngine` tap
- Human-like quality: prefers `Samantha (Premium)` or enhanced voices

### Glass UI
- `Material.ultraThinMaterial` with `.dark` color scheme for consistent deep glass
- Gradient borders: white top-left to transparent bottom-right
- Animated ambient orbs in background for depth
- Matches iOS 17+ aesthetic; will automatically use iOS 26 native glass when available

---

## Stage 2 Roadmap
- iCloud sync for conversations
- Widgets (morning briefing, quick chat)
- Shortcuts / Siri integration
- Calendar integration
- Custom system prompts per conversation
- Export conversations
- Web search tool integration
