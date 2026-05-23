import UIKit

struct AppInfo: Identifiable {
    let id: String
    let name: String
    let openURL: String
    let category: String
}

@MainActor
final class AppLauncherService {
    static let shared = AppLauncherService()
    private init() {}

    // Built-in iOS apps — always present, no canOpenURL check needed
    private let systemApps: [AppInfo] = [
        .init(id: "safari",   name: "Safari",    openURL: "https://",                         category: "browser"),
        .init(id: "maps",     name: "Maps",      openURL: "maps://",                          category: "navigation"),
        .init(id: "phone",    name: "Phone",     openURL: "tel://",                           category: "communication"),
        .init(id: "messages", name: "Messages",  openURL: "sms://",                           category: "communication"),
        .init(id: "mail",     name: "Mail",      openURL: "mailto://",                        category: "productivity"),
        .init(id: "facetime", name: "FaceTime",  openURL: "facetime://",                      category: "communication"),
        .init(id: "calendar", name: "Calendar",  openURL: "calshow://",                       category: "productivity"),
        .init(id: "notes",    name: "Notes",     openURL: "mobilenotes://",                   category: "productivity"),
        .init(id: "music",    name: "Music",     openURL: "music://",                         category: "entertainment"),
        .init(id: "podcasts", name: "Podcasts",  openURL: "podcasts://",                      category: "entertainment"),
        .init(id: "health",   name: "Health",    openURL: "x-apple-health://",               category: "health"),
        .init(id: "appstore", name: "App Store", openURL: "itms-apps://",                     category: "system"),
        .init(id: "settings", name: "Settings",  openURL: UIApplication.openSettingsURLString, category: "system"),
    ]

    // Third-party apps — checked with canOpenURL (requires LSApplicationQueriesSchemes)
    private let thirdPartyApps: [AppInfo] = [
        // Social
        .init(id: "instagram", name: "Instagram",    openURL: "instagram://",        category: "social"),
        .init(id: "twitter",   name: "X",            openURL: "twitter://",          category: "social"),
        .init(id: "facebook",  name: "Facebook",     openURL: "fb://",               category: "social"),
        .init(id: "tiktok",    name: "TikTok",       openURL: "tiktok://",           category: "social"),
        .init(id: "snapchat",  name: "Snapchat",     openURL: "snapchat://",         category: "social"),
        .init(id: "reddit",    name: "Reddit",       openURL: "reddit://",           category: "social"),
        .init(id: "linkedin",  name: "LinkedIn",     openURL: "linkedin://",         category: "social"),
        .init(id: "threads",   name: "Threads",      openURL: "barcelona://",        category: "social"),
        // Messaging
        .init(id: "whatsapp",  name: "WhatsApp",     openURL: "whatsapp://",         category: "communication"),
        .init(id: "telegram",  name: "Telegram",     openURL: "tg://",               category: "communication"),
        .init(id: "discord",   name: "Discord",      openURL: "discord://",          category: "communication"),
        .init(id: "slack",     name: "Slack",        openURL: "slack://",            category: "productivity"),
        .init(id: "zoom",      name: "Zoom",         openURL: "zoomus://",           category: "communication"),
        .init(id: "teams",     name: "Teams",        openURL: "msteams://",          category: "productivity"),
        // Productivity / Browser
        .init(id: "chrome",    name: "Chrome",       openURL: "googlechrome://",     category: "browser"),
        .init(id: "gmail",     name: "Gmail",        openURL: "googlegmail://",      category: "productivity"),
        .init(id: "gdrive",    name: "Google Drive", openURL: "googledrive://",      category: "productivity"),
        .init(id: "notion",    name: "Notion",       openURL: "notion://",           category: "productivity"),
        // Navigation
        .init(id: "gmaps",     name: "Google Maps",  openURL: "comgooglemaps://",    category: "navigation"),
        .init(id: "waze",      name: "Waze",         openURL: "waze://",             category: "navigation"),
        .init(id: "uber",      name: "Uber",         openURL: "uber://",             category: "navigation"),
        .init(id: "lyft",      name: "Lyft",         openURL: "lyft://",             category: "navigation"),
        // Entertainment
        .init(id: "youtube",   name: "YouTube",      openURL: "youtube://",          category: "entertainment"),
        .init(id: "netflix",   name: "Netflix",      openURL: "nflx://",             category: "entertainment"),
        .init(id: "spotify",   name: "Spotify",      openURL: "spotify://",          category: "entertainment"),
        .init(id: "twitch",    name: "Twitch",       openURL: "twitch://",           category: "entertainment"),
        .init(id: "shazam",    name: "Shazam",       openURL: "shazam://",           category: "entertainment"),
        .init(id: "tidal",     name: "Tidal",        openURL: "tidal://",            category: "entertainment"),
        // Finance
        .init(id: "venmo",     name: "Venmo",        openURL: "venmo://",            category: "finance"),
        .init(id: "paypal",    name: "PayPal",       openURL: "paypal://",           category: "finance"),
        .init(id: "cashapp",   name: "Cash App",     openURL: "cashme://",           category: "finance"),
        .init(id: "robinhood", name: "Robinhood",    openURL: "robinhood://",        category: "finance"),
        // Food
        .init(id: "doordash",  name: "DoorDash",     openURL: "doordash://",         category: "food"),
        .init(id: "ubereats",  name: "Uber Eats",    openURL: "ubereats://",         category: "food"),
        .init(id: "grubhub",   name: "Grubhub",      openURL: "grubhub://",          category: "food"),
        // Health / Fitness
        .init(id: "strava",    name: "Strava",       openURL: "strava://",           category: "health"),
        .init(id: "peloton",   name: "Peloton",      openURL: "pelotoncycle://",     category: "health"),
    ]

    func getInstalledApps(category: String? = nil) -> [AppInfo] {
        let checked = thirdPartyApps.filter { canOpen($0.openURL) }
        let all = systemApps + checked
        guard let cat = category, cat != "all", !cat.isEmpty else { return all }
        return all.filter { $0.category == cat }
    }

    func openApp(id: String) async -> Bool {
        let apps = systemApps + thirdPartyApps
        guard let app = apps.first(where: { $0.id == id }) else { return false }
        guard let url = URL(string: app.openURL) else { return false }
        return await withCheckedContinuation { cont in
            UIApplication.shared.open(url, options: [:]) { cont.resume(returning: $0) }
        }
    }

    private func canOpen(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return UIApplication.shared.canOpenURL(url)
    }
}
