import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var securityManager: SecurityManager

    var body: some View {
        ZStack {
            switch appState.authStep {
            case .splash:
                SplashView()
            case .login, .register:
                AuthView()
            case .twoFactor:
                TwoFactorView()
            case .biometric:
                BiometricUnlockView()
            case .unlocked:
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.authStep)
        .blur(radius: appState.blurSensitiveContent ? 20 : 0)
        .animation(.easeInOut(duration: 0.1), value: appState.blurSensitiveContent)
    }
}

// MARK: - Splash

struct SplashView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                Text("VaultX")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Secure Crypto Wallet")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
    }
}
