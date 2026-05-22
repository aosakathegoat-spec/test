import Foundation
import AuthenticationServices
import CryptoKit

// MARK: - Passkey / WebAuthn Service
// Passwordless authentication using FIDO2/WebAuthn passkeys.
// Stored in iCloud Keychain — works across all user's Apple devices.
// Phantom, MetaMask, and most crypto wallets have NO passkey support.

@available(iOS 16.0, *)
final class PasskeyService: NSObject, ObservableObject {
    static let shared = PasskeyService()
    private override init() { super.init() }

    private let relyingPartyID = "vaultx.app"
    private let relyingPartyName = "VaultX Wallet"

    @Published var isRegistered = false
    @Published var authError: String?

    // MARK: - Register Passkey

    func registerPasskey(userId: String, userName: String) async throws {
        let challenge = generateChallenge()
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: relyingPartyID)

        let registrationRequest = provider.createCredentialRegistrationRequest(
            challenge: challenge,
            name: userName,
            userID: Data(userId.utf8)
        )

        registrationRequest.userVerificationPreference = .required
        registrationRequest.attestationPreference = .none

        let controller = ASAuthorizationController(authorizationRequests: [registrationRequest])

        return try await withCheckedThrowingContinuation { continuation in
            PasskeyDelegate.shared.registrationContinuation = continuation
            controller.delegate = PasskeyDelegate.shared
            controller.presentationContextProvider = PasskeyDelegate.shared
            controller.performRequests()
        }
    }

    // MARK: - Authenticate with Passkey

    func authenticateWithPasskey(userId: String) async throws -> Bool {
        let challenge = generateChallenge()
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: relyingPartyID)

        let assertionRequest = provider.createCredentialAssertionRequest(challenge: challenge)
        assertionRequest.userVerificationPreference = .required

        let controller = ASAuthorizationController(authorizationRequests: [assertionRequest])

        return try await withCheckedThrowingContinuation { continuation in
            PasskeyDelegate.shared.assertionContinuation = continuation
            controller.delegate = PasskeyDelegate.shared
            controller.presentationContextProvider = PasskeyDelegate.shared
            controller.performRequests()
        }
    }

    // MARK: - Sign Transaction with Passkey
    // Use passkey to authorize high-value transactions — no separate biometric prompt needed.

    func signTransactionWithPasskey(txHash: Data) async throws -> Data {
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: relyingPartyID)
        let assertionRequest = provider.createCredentialAssertionRequest(challenge: txHash)
        assertionRequest.userVerificationPreference = .required

        let controller = ASAuthorizationController(authorizationRequests: [assertionRequest])

        let success: Bool = try await withCheckedThrowingContinuation { continuation in
            PasskeyDelegate.shared.assertionContinuation = continuation
            controller.delegate = PasskeyDelegate.shared
            controller.presentationContextProvider = PasskeyDelegate.shared
            controller.performRequests()
        }

        guard success else { throw PasskeyError.authenticationFailed }
        // Return signature bytes from assertion response
        return txHash  // Placeholder — production returns actual signature
    }

    private func generateChallenge() -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, 32, &bytes)
        return Data(bytes)
    }
}

// MARK: - Passkey Delegate

@available(iOS 16.0, *)
final class PasskeyDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    static let shared = PasskeyDelegate()

    var registrationContinuation: CheckedContinuation<Void, Error>?
    var assertionContinuation: CheckedContinuation<Bool, Error>?

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration {
            // Store credential ID for future use
            UserDefaults.standard.set(credential.credentialID, forKey: "passkeyCredentialID")
            registrationContinuation?.resume(returning: ())
        } else if authorization.credential is ASAuthorizationPlatformPublicKeyCredentialAssertion {
            assertionContinuation?.resume(returning: true)
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        registrationContinuation?.resume(throwing: error)
        assertionContinuation?.resume(throwing: error)
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first ?? UIWindow()
    }
}

enum PasskeyError: LocalizedError {
    case notSupported
    case authenticationFailed
    case notRegistered

    var errorDescription: String? {
        switch self {
        case .notSupported: return "Passkeys require iOS 16+ and iCloud Keychain"
        case .authenticationFailed: return "Passkey authentication failed"
        case .notRegistered: return "No passkey registered for this account"
        }
    }
}
