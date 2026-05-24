import Foundation

// MARK: - Supabase REST + Auth client

@MainActor
final class SupabaseClient: ObservableObject {
    static let shared = SupabaseClient()

    @Published var isAuthenticated = false

    private enum Keys {
        static let accessToken  = "supabase_access_token"
        static let refreshToken = "supabase_refresh_token"
        static let userID       = "supabase_user_id"
        static let tokenExpiry  = "supabase_token_expiry"
    }

    var userID: String? { KeychainService.get(Keys.userID) }

    private var accessToken: String? {
        get { KeychainService.get(Keys.accessToken) }
        set {
            if let v = newValue { KeychainService.set(v, for: Keys.accessToken) }
            else { KeychainService.delete(Keys.accessToken) }
        }
    }

    private var refreshToken: String? {
        get { KeychainService.get(Keys.refreshToken) }
        set {
            if let v = newValue { KeychainService.set(v, for: Keys.refreshToken) }
            else { KeychainService.delete(Keys.refreshToken) }
        }
    }

    private init() {
        isAuthenticated = accessToken != nil
        if isAuthenticated {
            Task { try? await refreshIfNeeded() }
        }
    }

    // MARK: - Auth

    func signInWithApple(idToken: String) async throws {
        let body = AppleSignInBody(provider: "apple", idToken: idToken)
        let response: AuthResponse = try await postAuth("token?grant_type=id_token", body: body)
        store(response)
    }

    func refreshSession() async throws {
        guard let rt = refreshToken else { throw SupabaseError.notAuthenticated }
        let body = RefreshBody(refreshToken: rt)
        let response: AuthResponse = try await postAuth("token?grant_type=refresh_token", body: body)
        store(response)
    }

    func signOut() {
        KeychainService.delete(Keys.accessToken)
        KeychainService.delete(Keys.refreshToken)
        KeychainService.delete(Keys.userID)
        UserDefaults.standard.removeObject(forKey: Keys.tokenExpiry)
        isAuthenticated = false
    }

    private func refreshIfNeeded() async throws {
        let expiry = UserDefaults.standard.double(forKey: Keys.tokenExpiry)
        guard expiry > 0 else { return }
        let expiresAt = Date(timeIntervalSince1970: expiry)
        if Date().addingTimeInterval(60) > expiresAt {
            try await refreshSession()
        }
    }

    private func store(_ response: AuthResponse) {
        accessToken  = response.accessToken
        refreshToken = response.refreshToken
        KeychainService.set(response.user.id, for: Keys.userID)
        let expiry = Date().addingTimeInterval(Double(response.expiresIn)).timeIntervalSince1970
        UserDefaults.standard.set(expiry, forKey: Keys.tokenExpiry)
        isAuthenticated = true
    }

    // MARK: - REST helpers

    func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        try await request(method: "GET", path: path, query: query, body: Optional<Empty>.none)
    }

    func post<B: Encodable, T: Decodable>(_ path: String, body: B, prefer: String = "return=representation") async throws -> T {
        try await request(method: "POST", path: path, query: [], body: body, prefer: prefer)
    }

    func upsert<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        try await request(method: "POST", path: path, query: [], body: body,
                          prefer: "resolution=merge-duplicates,return=representation")
    }

    func delete(_ path: String, query: [URLQueryItem]) async throws {
        let _: [Empty] = try await request(method: "DELETE", path: path, query: query, body: Optional<Empty>.none)
    }

    // MARK: - Core request

    private struct Empty: Codable {}

    private func request<B: Encodable, T: Decodable>(
        method: String,
        path: String,
        query: [URLQueryItem],
        body: B?,
        prefer: String = "return=representation",
        retried: Bool = false
    ) async throws -> T {
        guard var comps = URLComponents(string: "\(SupabaseConfig.restURL)/\(path)") else {
            throw SupabaseError.invalidURL
        }
        if !query.isEmpty { comps.queryItems = query }
        guard let url = comps.url else { throw SupabaseError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(prefer, forHTTPHeaderField: "Prefer")
        if let token = accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body { req.httpBody = try JSONEncoder().encode(body) }

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw SupabaseError.invalidResponse }

        if http.statusCode == 401, !retried {
            try await refreshSession()
            return try await self.request(method: method, path: path, query: query,
                                          body: body, prefer: prefer, retried: true)
        }

        guard (200..<300).contains(http.statusCode) else {
            throw SupabaseError.httpError(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }

        // Empty body or null — return Empty/empty array as appropriate
        if data.isEmpty || data == Data("null".utf8) {
            if T.self == Empty.self { return Empty() as! T }
            if T.self == [Empty].self { return [] as! T }
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let str = try decoder.singleValueContainer().decode(String.self)
            let fmts: [ISO8601DateFormatter] = [
                { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f }(),
                { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]; return f }()
            ]
            for fmt in fmts { if let d = fmt.date(from: str) { return d } }
            throw DecodingError.dataCorruptedError(in: try decoder.singleValueContainer(),
                                                   debugDescription: "Cannot parse date: \(str)")
        }
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }

    private func postAuth<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        guard let url = URL(string: "\(SupabaseConfig.authURL)/\(path)") else {
            throw SupabaseError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode)
        else {
            throw SupabaseError.authFailed(String(data: data, encoding: .utf8) ?? "Auth error")
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }
}

// MARK: - Wire types

struct AuthResponse: Decodable {
    let accessToken:  String
    let tokenType:    String
    let expiresIn:    Int
    let refreshToken: String
    let user:         SupabaseUser
}

struct SupabaseUser: Decodable { let id: String }

private struct AppleSignInBody: Encodable {
    let provider:  String
    let idToken:   String
    enum CodingKeys: String, CodingKey { case provider, idToken = "id_token" }
}

private struct RefreshBody: Encodable {
    let refreshToken: String
    enum CodingKeys: String, CodingKey { case refreshToken = "refresh_token" }
}

// MARK: - Errors

enum SupabaseError: Error, LocalizedError {
    case notAuthenticated
    case invalidURL
    case invalidResponse
    case httpError(Int, String)
    case authFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:          return "Not signed in to Supabase"
        case .invalidURL:                return "Invalid URL"
        case .invalidResponse:           return "Invalid server response"
        case .httpError(let c, let m):   return "HTTP \(c): \(m)"
        case .authFailed(let m):         return "Auth failed: \(m)"
        }
    }
}
