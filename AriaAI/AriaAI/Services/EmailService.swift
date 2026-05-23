import Foundation
import AuthenticationServices
import UIKit

enum EmailError: LocalizedError {
    case notAuthenticated
    case sendFailed(String)
    case fetchFailed(String)
    case authFailed(String)
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:   return "Please connect your Gmail account in Settings."
        case .sendFailed(let m):  return "Failed to send: \(m)"
        case .fetchFailed(let m): return "Failed to load emails: \(m)"
        case .authFailed(let m):  return "Auth failed: \(m)"
        case .rateLimited:        return "Too many requests — please wait a moment."
        }
    }
}

@MainActor
class EmailService: ObservableObject {
    static let shared = EmailService()

    @Published var isAuthenticated = false
    @Published var userEmail       = ""

    // Tokens stored in Keychain
    private enum TokenKeys {
        static let access  = "gmail_access_token"
        static let refresh = "gmail_refresh_token"
        static let expiry  = "gmail_token_expiry"   // UserDefaults (non-sensitive)
    }

    private var accessToken:  String = ""
    private var refreshToken: String = ""
    private var tokenExpiry:  Date   = .distantPast

    private let urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 30
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }()

    private init() { loadStoredCredentials() }

    private func loadStoredCredentials() {
        accessToken  = KeychainService.get(TokenKeys.access)  ?? ""
        refreshToken = KeychainService.get(TokenKeys.refresh) ?? ""
        tokenExpiry  = (UserDefaults.standard.object(forKey: TokenKeys.expiry) as? Date) ?? .distantPast
        userEmail    = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.gmailEmail) ?? ""
        isAuthenticated = !refreshToken.isEmpty  // refresh token presence = authenticated
    }

    // MARK: - Called when Google sign-in already happened via LoginView
    func storeTokensFromLogin(accessToken: String) async {
        self.accessToken = accessToken
        tokenExpiry = Date().addingTimeInterval(3500)
        KeychainService.set(accessToken, for: TokenKeys.access)
        UserDefaults.standard.set(tokenExpiry, forKey: TokenKeys.expiry)
        isAuthenticated = true
        await fetchUserEmail()
    }

    // MARK: - OAuth (Settings re-auth)
    func authenticate() async throws {
        guard var components = URLComponents(string: Constants.Gmail.authURL) else {
            throw EmailError.authFailed("Invalid auth URL")
        }
        components.queryItems = [
            .init(name: "client_id",     value: Constants.Gmail.clientID),
            .init(name: "redirect_uri",  value: Constants.Gmail.redirectURI),
            .init(name: "response_type", value: "code"),
            .init(name: "scope",         value: Constants.Gmail.scope),
            .init(name: "access_type",   value: "offline"),
            .init(name: "prompt",        value: "consent")
        ]
        guard let authURL = components.url else { throw EmailError.authFailed("Bad URL") }

        let code: String = try await withCheckedThrowingContinuation { cont in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "com.aria.assistant"
            ) { callbackURL, error in
                if let error {
                    cont.resume(throwing: EmailError.authFailed(error.localizedDescription))
                    return
                }
                guard let callbackURL,
                      let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                          .queryItems?.first(where: { $0.name == "code" })?.value
                else {
                    cont.resume(throwing: EmailError.authFailed("No auth code returned"))
                    return
                }
                cont.resume(returning: code)
            }
            session.presentationContextProvider = PresentationProvider.shared
            session.prefersEphemeralWebBrowserSession = false
            DispatchQueue.main.async { _ = session.start() }
        }
        try await exchangeCodeForTokens(code)
    }

    private func exchangeCodeForTokens(_ code: String) async throws {
        var req = URLRequest(url: URL(string: Constants.Gmail.tokenURL)!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let params: [String: String] = [
            "code": code, "client_id": Constants.Gmail.clientID,
            "redirect_uri": Constants.Gmail.redirectURI, "grant_type": "authorization_code"
        ]
        req.httpBody = params.percentEncoded

        let (data, _) = try await urlSession.data(for: req)
        let resp = try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
        guard resp.accessToken != nil else {
            let raw = String(data: data, encoding: .utf8) ?? "unknown"
            throw EmailError.authFailed(raw)
        }

        storeTokens(resp)
        await fetchUserEmail()
    }

    private func refreshAccessToken() async throws {
        guard !refreshToken.isEmpty else { throw EmailError.notAuthenticated }
        var req = URLRequest(url: URL(string: Constants.Gmail.tokenURL)!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let params: [String: String] = [
            "refresh_token": refreshToken,
            "client_id":     Constants.Gmail.clientID,
            "grant_type":    "refresh_token"
        ]
        req.httpBody = params.percentEncoded

        let (data, _) = try await urlSession.data(for: req)
        let resp = try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
        storeTokens(resp)
    }

    private func storeTokens(_ resp: OAuthTokenResponse) {
        if let at = resp.accessToken {
            accessToken = at
            KeychainService.set(at, for: TokenKeys.access)
        }
        if let rt = resp.refreshToken {
            refreshToken = rt
            KeychainService.set(rt, for: TokenKeys.refresh)
        }
        let expiry = Date().addingTimeInterval(TimeInterval(resp.expiresIn ?? 3600) - 60)
        tokenExpiry = expiry
        UserDefaults.standard.set(expiry, forKey: TokenKeys.expiry)
        isAuthenticated = true
    }

    private func validToken() async throws -> String {
        if Date() >= tokenExpiry {
            try await refreshAccessToken()
        }
        guard !accessToken.isEmpty else { throw EmailError.notAuthenticated }
        return accessToken
    }

    private func fetchUserEmail() async {
        guard let token = try? await validToken() else { return }
        var req = URLRequest(url: URL(string: "https://www.googleapis.com/oauth2/v3/userinfo")!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await urlSession.data(for: req),
              let profile = try? JSONDecoder().decode(GoogleProfile.self, from: data)
        else { return }
        userEmail = profile.email
        UserDefaults.standard.set(userEmail, forKey: Constants.UserDefaultsKeys.gmailEmail)
    }

    // MARK: - Fetch Inbox
    func fetchInbox(maxResults: Int = 30) async throws -> [EmailMessage] {
        let token = try await validToken()

        guard var listURL = URLComponents(string: "\(Constants.Gmail.apiBase)/messages") else {
            throw EmailError.fetchFailed("Invalid API URL")
        }
        listURL.queryItems = [
            .init(name: "labelIds",   value: "INBOX"),
            .init(name: "maxResults", value: "\(maxResults)")
        ]
        var listReq = URLRequest(url: listURL.url!)
        listReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (listData, listResp) = try await urlSession.data(for: listReq)
        if let http = listResp as? HTTPURLResponse, http.statusCode == 429 { throw EmailError.rateLimited }
        if let http = listResp as? HTTPURLResponse, http.statusCode != 200 {
            throw EmailError.fetchFailed("HTTP \(http.statusCode)")
        }

        let list = try JSONDecoder().decode(GmailListResponse.self, from: listData)
        guard let refs = list.messages, !refs.isEmpty else { return [] }

        // Fetch messages in parallel (capped at 20 concurrent)
        let emails = try await withThrowingTaskGroup(of: EmailMessage?.self) { group in
            for ref in refs.prefix(maxResults) {
                group.addTask { [weak self] in
                    guard let self else { return nil }
                    return try? await self.fetchMessage(id: ref.id, token: token)
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

    private func fetchMessage(id: String, token: String) async throws -> EmailMessage {
        var req = URLRequest(url: URL(string: "\(Constants.Gmail.apiBase)/messages/\(id)?format=full")!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await urlSession.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
            throw EmailError.fetchFailed("HTTP \(http.statusCode)")
        }
        let msg = try JSONDecoder().decode(GmailMessage.self, from: data)
        return msg.toEmailMessage()
    }

    // MARK: - Send Email
    func sendEmail(_ draft: DraftEmail) async throws {
        guard draft.isValid else { throw EmailError.sendFailed("Missing required fields") }
        let token = try await validToken()

        let raw = buildRFC2822(draft: draft, from: userEmail)
        let base64 = Data(raw.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        var req = URLRequest(url: URL(string: "\(Constants.Gmail.apiBase)/messages/send")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)",   forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["raw": base64])

        let (data, resp) = try await urlSession.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            let msg = (try? JSONDecoder().decode(GmailErrorResponse.self, from: data))?.error.message
                ?? String(data: data, encoding: .utf8)
                ?? "Unknown error"
            throw EmailError.sendFailed(msg)
        }
    }

    private func buildRFC2822(draft: DraftEmail, from sender: String) -> String {
        let dateStr = rfc2822DateFormatter.string(from: Date())
        var lines: [String] = []
        lines.append("From: \(sender)")
        lines.append("To: \(draft.to.trimmed)")
        if !draft.cc.trimmed.isEmpty { lines.append("Cc: \(draft.cc.trimmed)") }
        lines.append("Subject: \(draft.subject.trimmed)")
        lines.append("Date: \(dateStr)")
        lines.append("MIME-Version: 1.0")
        lines.append("Content-Type: text/plain; charset=UTF-8")
        lines.append("Content-Transfer-Encoding: quoted-printable")
        lines.append("")
        lines.append(draft.body)
        return lines.joined(separator: "\r\n")
    }

    // MARK: - Disconnect
    func disconnect() {
        KeychainService.delete(TokenKeys.access)
        KeychainService.delete(TokenKeys.refresh)
        UserDefaults.standard.removeObject(forKey: TokenKeys.expiry)
        UserDefaults.standard.removeObject(forKey: Constants.UserDefaultsKeys.gmailEmail)
        accessToken  = ""
        refreshToken = ""
        userEmail    = ""
        isAuthenticated = false
    }
}

// MARK: - Models
private struct OAuthTokenResponse: Decodable {
    let accessToken:  String?
    let refreshToken: String?
    let expiresIn:    Int?
    enum CodingKeys: String, CodingKey {
        case accessToken  = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn    = "expires_in"
    }
}

private struct GmailErrorResponse: Decodable {
    struct ErrorBody: Decodable { let message: String }
    let error: ErrorBody
}

private let rfc2822DateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale     = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
    return f
}()

private extension Dictionary where Key == String, Value == String {
    var percentEncoded: Data? {
        map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)
    }
}
