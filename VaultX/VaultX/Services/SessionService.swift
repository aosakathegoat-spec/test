import Foundation

final class SessionService {
    static let shared = SessionService()
    private let keychain = KeychainService.shared
    private init() {}

    func hasValidSession() -> Bool {
        guard let token = try? keychain.loadAuthToken() else { return false }
        return !isTokenExpired(token)
    }

    func saveSession(accessToken: String, refreshToken: String) {
        try? keychain.saveAuthToken(accessToken)
        try? keychain.saveRefreshToken(refreshToken)
    }

    func invalidateSession() {
        keychain.clearAuthTokens()
    }

    private func isTokenExpired(_ token: String) -> Bool {
        let parts = token.components(separatedBy: ".")
        guard parts.count == 3,
              let payloadData = Data(base64Encoded: parts[1].paddedBase64),
              let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let exp = payload["exp"] as? TimeInterval
        else { return true }

        return Date().timeIntervalSince1970 >= exp
    }
}

extension String {
    var paddedBase64: String {
        let remainder = count % 4
        guard remainder != 0 else { return self }
        return self + String(repeating: "=", count: 4 - remainder)
    }
}
