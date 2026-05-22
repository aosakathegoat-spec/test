import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var portfolioService = PortfolioService.shared
    @EnvironmentObject var walletManager: WalletManager

    var body: some View {
        TabView(selection: $appState.activeTab) {
            PortfolioView()
                .tabItem { Label("Portfolio", systemImage: "chart.pie.fill") }
                .tag(AppState.TabItem.portfolio)

            WalletListView()
                .tabItem { Label("Wallets", systemImage: "wallet.pass.fill") }
                .tag(AppState.TabItem.wallets)

            TradingHubView()
                .tabItem { Label("Trade", systemImage: "arrow.left.arrow.right.circle.fill") }
                .tag(AppState.TabItem.trade)

            EarnView()
                .tabItem { Label("Earn", systemImage: "sparkles") }
                .tag(AppState.TabItem.earn)

            BridgeView()
                .tabItem { Label("Bridge", systemImage: "arrow.triangle.2.circlepath.circle.fill") }
                .tag(AppState.TabItem.bridge)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(AppState.TabItem.settings)
        }
        .tint(.purple)
        .preferredColorScheme(.dark)
        .task {
            await walletManager.refreshBalances()
            await portfolioService.refreshPortfolio(wallets: walletManager.wallets)
        }
    }
}
