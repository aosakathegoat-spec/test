import Foundation
import AuthenticationServices
import UIKit

enum EmailError: LocalizedError {
    case notAuthenticated
    case sendFailed(String)
    case fetchFailed(String)
    case authFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:   return "Please connect your Gmail account in Settings."
        case .sendFailed(let m):  return "Failed to send email: \(m)"
        case .fetchFailed(let m): return "Failed to fetch emails: \(m)"
        case .authFailed(let m):  return "Authentication failed: \(m)"
        }
    }
}

@MainActor
class EmailService: ObservableObject {
    static let shared = EmailService()

    @Published var isAuthenticated = false
    @Published var userEmail = ""
    @Published var isLoading = false

    private var accessToken: String = ""
    private var refreshToken: String = ""
    private var tokenExpiry: Date = Date()

    private init() {
        loadStoredCredentials()
    }

    private func loadStoredCredentials() {
        let defaults = UserDefaults.standard
        accessToken  = defaults.string(forKey: Constants.UserDefaultsKeys.gmailToken)   ?? ""
        refreshToken = defaults.string(forKey: Constants.UserDefaultsKeys.gmailRefresh) ?? ""
        userEmail    = defaults.string(forKey: Constants.UserDefaultsKeys.gmailEmail)   ?? ""
        isAuthenticated = !accessToken.isEmpty
    }

    // MARK: - OAuth
    func authenticate(from viewController: UIViewController?) async throws {
        let state = UUID().uuidString
        var components = URLComponents(string: Constants.Gmail.authURL)!
        components.queryItems = [
            .init(name: "client_id",     value: Constants.Gmail.clientID),
            .init(name: "redirect_uri",  value: Constants.Gmail.redirectURI),
            .init(name: "response_type", value: "code"),
            .init(name: "scope",         value: Constants.Gmail.scope),
            .init(name: "state",         value: state),
            .init(name: "access_type",   value: "offline"),
            .init(name: "prompt",        value: "consent")
        ]

        guard let authURL = components.url else { throw EmailError.authFailed("Invalid URL") }

        let code: String = try await withCheckedThrowingContinuation { cont in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "com.aria.assistant"
            ) { callbackURL, error in
                if let error { cont.resume(throwing: EmailError.authFailed(error.localizedDescription)); return }
                guard let url = callbackURL,
                      let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                        .queryItems?.first(where: { $0.name == "code" })?.value
                else { cont.resume(throwing: EmailError.authFailed("No auth code")); return }
                cont.resume(returning: code)
            }
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }

        try await exchangeCodeForTokens(code)
    }

    private func exchangeCodeForTokens(_ code: String) async throws {
        var request = URLRequest(url: URL(string: Constants.Gmail.tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let params = [
            "code":          code,
            "client_id":     Constants.Gmail.clientID,
            "redirect_uri":  Constants.Gmail.redirectURI,
            "grant_type":    "authorization_code"
        ]
        request.httpBody = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(OAuthResponse.self, from: data)

        accessToken  = response.accessToken
        refreshToken = response.refreshToken ?? refreshToken
        tokenExpiry  = Date().addingTimeInterval(TimeInterval(response.expiresIn ?? 3600))

        let defaults = UserDefaults.standard
        defaults.set(accessToken,  forKey: Constants.UserDefaultsKeys.gmailToken)
        defaults.set(refreshToken, forKey: Constants.UserDefaultsKeys.gmailRefresh)
        isAuthenticated = true
        await fetchUserEmail()
    }

    private func refreshAccessToken() async throws {
        guard !refreshToken.isEmpty else { throw EmailError.notAuthenticated }

        var request = URLRequest(url: URL(string: Constants.Gmail.tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let params = [
            "refresh_token": refreshToken,
            "client_id":     Constants.Gmail.clientID,
            "grant_type":    "refresh_token"
        ]
        request.httpBody = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(OAuthResponse.self, from: data)

        accessToken = response.accessToken
        tokenExpiry = Date().addingTimeInterval(TimeInterval(response.expiresIn ?? 3600))
        UserDefaults.standard.set(accessToken, forKey: Constants.UserDefaultsKeys.gmailToken)
    }

    private func validToken() async throws -> String {
        if Date() >= tokenExpiry.addingTimeInterval(-60) {
            try await refreshAccessToken()
        }
        guard !accessToken.isEmpty else { throw EmailError.notAuthenticated }
        return accessToken
    }

    private func fetchUserEmail() async {
        guard let token = try? await validToken() else { return }
        var request = URLRequest(url: URL(string: "https://www.googleapis.com/oauth2/v2/userinfo")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONDecoder().decode(UserInfoResponse.self, from: data)
        else { return }
        userEmail = json.email
        UserDefaults.standard.set(userEmail, forKey: Constants.UserDefaultsKeys.gmailEmail)
    }

    // MARK: - Fetch Inbox
    func fetchInbox(maxResults: Int = 30) async throws -> [EmailMessage] {
        let token = try await validToken()

        var listURL = URLComponents(string: "\(Constants.Gmail.apiBase)/messages")!
        listURL.queryItems = [
            .init(name: "labelIds",   value: "INBOX"),
            .init(name: "maxResults", value: "\(maxResults)"),
        ]

        var listReq = URLRequest(url: listURL.url!)
        listReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (listData, _) = try await URLSession.shared.data(for: listReq)
        let listResponse = try JSONDecoder().decode(GmailListResponse.self, from: listData)

        guard let refs = listResponse.messages else { return [] }

        let emails = try await withThrowingTaskGroup(of: EmailMessage?.self) { group in
            for ref in refs.prefix(maxResults) {
                group.addTask {
                    try await self.fetchMessage(id: ref.id, token: token)
                }
            }
            var result: [EmailMessage] = []
            for try await email in group {
                if let e = email { result.append(e) }
            }
            return result.sorted { $0.date > $1.date }
        }
        return emails
    }

    private func fetchMessage(id: String, token: String) async throws -> EmailMessage? {
        var req = URLRequest(url: URL(string: "\(Constants.Gmail.apiBase)/messages/\(id)?format=full")!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: req)
        let gmailMsg = try JSONDecoder().decode(GmailMessage.self, from: data)
        return gmailMsg.toEmailMessage()
    }

    // MARK: - Send Email
    func sendEmail(_ draft: DraftEmail) async throws {
        let token = try await validToken()

        let rawMessage = buildRawMessage(from: draft, senderEmail: userEmail)
        let base64 = rawMessage.data(using: .utf8)!
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        var request = URLRequest(url: URL(string: "\(Constants.Gmail.apiBase)/messages/send")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)",   forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["raw": base64])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw EmailError.sendFailed(msg)
        }
    }

    private func buildRawMessage(from draft: DraftEmail, senderEmail: String) -> String {
        let dateStr = RFC2822DateFormatter.string(from: Date())
        var raw = ""
        raw += "From: \(senderEmail)\r\n"
        raw += "To: \(draft.to)\r\n"
        if !draft.cc.trimmed.isEmpty { raw += "Cc: \(draft.cc)\r\n" }
        raw += "Subject: \(draft.subject)\r\n"
        raw += "Date: \(dateStr)\r\n"
        raw += "MIME-Version: 1.0\r\n"
        raw += "Content-Type: text/plain; charset=UTF-8\r\n"
        raw += "Content-Transfer-Encoding: 8bit\r\n"
        raw += "\r\n"
        raw += draft.body
        return raw
    }

    func disconnect() {
        accessToken  = ""
        refreshToken = ""
        userEmail    = ""
        isAuthenticated = false
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Constants.UserDefaultsKeys.gmailToken)
        defaults.removeObject(forKey: Constants.UserDefaultsKeys.gmailRefresh)
        defaults.removeObject(forKey: Constants.UserDefaultsKeys.gmailEmail)
    }
}

// MARK: - Models
private struct OAuthResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int?
    enum CodingKeys: String, CodingKey {
        case accessToken  = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn    = "expires_in"
    }
}

private struct UserInfoResponse: Decodable {
    let email: String
}

private let RFC2822DateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
    return f
}()
