import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject private var auth: AuthService
    @State private var logoScale: CGFloat   = 0.6
    @State private var logoOpacity: Double  = 0
    @State private var textOffset: CGFloat  = 30
    @State private var buttonsOpacity: Double = 0
    @State private var glowPulse = false
    @State private var showGoogleFlow = false

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            VStack(spacing: 0) {
                Spacer()

                // Logo
                logoSection
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)

                Spacer().frame(height: 40)

                // Tagline
                VStack(spacing: 8) {
                    Text("Aria")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("Your intelligent AI assistant")
                        .font(Theme.Typography.body())
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .offset(y: textOffset)
                .opacity(logoOpacity)

                Spacer()

                // Auth buttons
                VStack(spacing: 14) {
                    appleSignInButton
                    googleSignInButton

                    if let err = auth.authError {
                        Text(err)
                            .font(Theme.Typography.caption())
                            .foregroundStyle(Theme.Colors.error)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .opacity(buttonsOpacity)
                .padding(.horizontal, 32)

                Spacer().frame(height: 24)

                // Legal
                Text("By continuing, you agree to our Terms of Service and Privacy Policy.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .opacity(buttonsOpacity)

                Spacer().frame(height: 48)
            }
        }
        .onAppear { startAnimations() }
        .sheet(isPresented: $showGoogleFlow) {
            GoogleSignInWebView(auth: auth, isPresented: $showGoogleFlow)
        }
    }

    // MARK: - Logo
    private var logoSection: some View {
        ZStack {
            // Outer glow ring
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "#4F8EF7").opacity(glowPulse ? 0.35 : 0.2),
                            .clear
                        ],
                        center: .center, startRadius: 30, endRadius: 80
                    )
                )
                .frame(width: 160, height: 160)
                .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: glowPulse)

            // Glass disc
            Circle()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .frame(width: 96, height: 96)
                .overlay {
                    Circle().stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.45), .white.opacity(0.08)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ), lineWidth: 1.5
                    )
                }
                .shadow(color: Color(hex: "#4F8EF7").opacity(0.45), radius: 24, x: 0, y: 8)

            // Inner gradient
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#4F8EF7"), Color(hex: "#9B6DFF")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(width: 72, height: 72)
                .shadow(color: Color(hex: "#4F8EF7").opacity(0.6), radius: 16)

            Text("A")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Sign in with Apple
    private var appleSignInButton: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.fullName, .email]
            auth.isSigningIn = true
        } onCompletion: { result in
            switch result {
            case .success(let auth):
                guard let cred = auth.credential as? ASAuthorizationAppleIDCredential else { return }
                self.auth.handleAppleCredential(cred)
            case .failure(let error):
                self.auth.handleAppleError(error)
            }
        }
        .signInWithAppleButtonStyle(.white)
        .frame(height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }

    // MARK: - Google button
    private var googleSignInButton: some View {
        Button { showGoogleFlow = true } label: {
            HStack(spacing: 12) {
                // Google G
                ZStack {
                    Circle().fill(.white).frame(width: 26, height: 26)
                    Text("G")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(hex: "#4285F4"))
                }
                Text("Continue with Google")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .frame(height: 56)
            .background(.ultraThinMaterial)
            .environment(\.colorScheme, .dark)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(auth.isSigningIn)
    }

    // MARK: - Entrance animations
    private func startAnimations() {
        glowPulse = true
        withAnimation(.spring(response: 0.7, dampingFraction: 0.65).delay(0.1)) {
            logoScale   = 1.0
            logoOpacity = 1.0
            textOffset  = 0
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.55)) {
            buttonsOpacity = 1.0
        }
    }
}

// MARK: - Google OAuth Web View
struct GoogleSignInWebView: View {
    @ObservedObject var auth: AuthService
    @Binding var isPresented: Bool
    @State private var didAttempt = false

    var body: some View {
        ZStack {
            SheetGlassBackground()
            VStack(spacing: Theme.Spacing.lg) {
                Image(systemName: "globe")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#4285F4"), Color(hex: "#0F9D58")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                Text("Redirecting to Google…")
                    .font(Theme.Typography.title3(.medium))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("A browser window will open to complete sign-in.")
                    .font(Theme.Typography.body())
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xl)
            }
        }
        .onAppear {
            guard !didAttempt else { return }
            didAttempt = true
            Task { await startGoogleAuth() }
        }
    }

    private func startGoogleAuth() async {
        guard var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth") else { return }
        components.queryItems = [
            .init(name: "client_id",     value: Constants.Gmail.clientID),
            .init(name: "redirect_uri",  value: Constants.Gmail.redirectURI),
            .init(name: "response_type", value: "code"),
            .init(name: "scope",         value: "openid profile email \(Constants.Gmail.scope)"),
            .init(name: "access_type",   value: "offline"),
            .init(name: "prompt",        value: "select_account")
        ]
        guard let url = components.url else { isPresented = false; return }

        do {
            let code: String = try await withCheckedThrowingContinuation { cont in
                let session = ASWebAuthenticationSession(
                    url: url,
                    callbackURLScheme: "com.aria.assistant"
                ) { callbackURL, error in
                    if let error {
                        cont.resume(throwing: error)
                        return
                    }
                    guard let callbackURL,
                          let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                            .queryItems?.first(where: { $0.name == "code" })?.value
                    else {
                        cont.resume(throwing: URLError(.badServerResponse))
                        return
                    }
                    cont.resume(returning: code)
                }
                session.presentationContextProvider = PresentationProvider.shared
                session.prefersEphemeralWebBrowserSession = false
                DispatchQueue.main.async { _ = session.start() }
            }

            // Exchange code for tokens and profile
            let (accessToken, profile) = try await exchangeAndFetchProfile(code: code)
            // Store refresh token in Gmail service for later inbox use
            await EmailService.shared.storeTokensFromLogin(accessToken: accessToken)
            auth.signInWithGoogle(id: profile.id, name: profile.name, email: profile.email)
        } catch {
            let asError = error as? ASAuthorizationError
            if asError?.code != .canceled {
                auth.authError = error.localizedDescription
            }
        }
        isPresented = false
    }

    private func exchangeAndFetchProfile(code: String) async throws -> (String, GoogleProfile) {
        // Exchange code for tokens
        var tokenReq = URLRequest(url: URL(string: Constants.Gmail.tokenURL)!)
        tokenReq.httpMethod = "POST"
        tokenReq.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let params = [
            "code": code, "client_id": Constants.Gmail.clientID,
            "redirect_uri": Constants.Gmail.redirectURI, "grant_type": "authorization_code"
        ]
        tokenReq.httpBody = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)

        let (tokenData, _) = try await URLSession.shared.data(for: tokenReq)
        let tokenResp = try JSONDecoder().decode(GoogleTokenResponse.self, from: tokenData)

        // Fetch profile
        var profileReq = URLRequest(url: URL(string: "https://www.googleapis.com/oauth2/v3/userinfo")!)
        profileReq.setValue("Bearer \(tokenResp.accessToken)", forHTTPHeaderField: "Authorization")
        let (profileData, _) = try await URLSession.shared.data(for: profileReq)
        let profile = try JSONDecoder().decode(GoogleProfile.self, from: profileData)

        return (tokenResp.accessToken, profile)
    }
}

// MARK: - Models
private struct GoogleTokenResponse: Decodable {
    let accessToken:  String
    let refreshToken: String?
    let expiresIn:    Int?
    enum CodingKeys: String, CodingKey {
        case accessToken  = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn    = "expires_in"
    }
}

struct GoogleProfile: Decodable {
    let id:    String
    let name:  String
    let email: String
    enum CodingKeys: String, CodingKey {
        case id = "sub", name, email
    }
}

// MARK: - Presentation provider singleton
final class PresentationProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = PresentationProvider()
    private override init() {}

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
