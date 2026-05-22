import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var portfolioService = PortfolioService.shared
    @EnvironmentObject var walletManager: WalletManager

    var body: some View {
        TabView(selection: $appState.activeTab) {
            PortfolioView()
                .tabItem {
                    Label("Portfolio", systemImage: "chart.pie.fill")
                }
                .tag(AppState.TabItem.portfolio)

            WalletListView()
                .tabItem {
                    Label("Wallets", systemImage: "wallet.pass.fill")
                }
                .tag(AppState.TabItem.wallets)

            SendView()
                .tabItem {
                    Label("Send", systemImage: "paperplane.fill")
                }
                .tag(AppState.TabItem.send)

            ReceiveView()
                .tabItem {
                    Label("Receive", systemImage: "qrcode")
                }
                .tag(AppState.TabItem.receive)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
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
