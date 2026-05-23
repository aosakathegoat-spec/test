import SwiftUI

@main
struct AriaAIApp: App {
    @StateObject private var appState  = AppState.shared
    @StateObject private var authService = AuthService.shared

    init() { configureAppearance() }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(authService)
                .preferredColorScheme(.dark)
        }
    }

    private func configureAppearance() {
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        navAppearance.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]
        UINavigationBar.appearance().standardAppearance   = navAppearance
        UINavigationBar.appearance().compactAppearance    = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().tintColor = UIColor(Color(hex: "#4F8EF7"))

        UITabBar.appearance().isHidden = true
        UITableView.appearance().backgroundColor     = .clear
        UITableViewCell.appearance().backgroundColor = .clear
        UITextField.appearance().tintColor = UIColor(Color(hex: "#4F8EF7"))
        UITextView.appearance().tintColor  = UIColor(Color(hex: "#4F8EF7"))
    }
}
