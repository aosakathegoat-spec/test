import SwiftUI
import LocalAuthentication

@main
struct VaultXApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var walletManager = WalletManager()
    @StateObject private var securityManager = SecurityManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(walletManager)
                .environmentObject(securityManager)
                .onAppear { appState.initialize() }
                .onChange(of: scenePhase) { phase in
                    handleScenePhase(phase)
                }
        }
    }

    private func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background:
            appState.lockApp()
            securityManager.clearSensitiveMemory()
        case .inactive:
            appState.blurSensitiveContent = true
        case .active:
            appState.blurSensitiveContent = false
            if appState.isLocked {
                appState.requireBiometricUnlock()
            }
        @unknown default:
            break
        }
    }
}
