import Foundation

/// Fill in your Supabase project values — Settings → API in the Supabase dashboard.
enum SupabaseConfig {
    static let projectURL = "https://YOUR_PROJECT_REF.supabase.co"
    static let anonKey    = "YOUR_SUPABASE_ANON_KEY"

    static var restURL:     String { "\(projectURL)/rest/v1" }
    static var authURL:     String { "\(projectURL)/auth/v1" }
    static var realtimeURL: String {
        let host = projectURL.replacingOccurrences(of: "https://", with: "")
        return "wss://\(host)/realtime/v1/websocket?apikey=\(anonKey)&vsn=1.0.0"
    }
}
