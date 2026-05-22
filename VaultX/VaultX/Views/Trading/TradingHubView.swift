import SwiftUI

struct TradingHubView: View {
    @EnvironmentObject var walletManager: WalletManager
    @State private var showingBuy = false
    @State private var showingSell = false
    @State private var selectedTab: TradingTab = .swap

    enum TradingTab: String, CaseIterable {
        case swap = "Swap"
        case dca = "Auto-Invest"
        case approvals = "Approvals"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 0) {
                    quickActions
                    tabBar
                    tabContent
                }
            }
            .navigationTitle("Trade")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingBuy) { BuyView().environmentObject(walletManager) }
        .sheet(isPresented: $showingSell) { SellView().environmentObject(walletManager) }
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        HStack(spacing: 12) {
            quickActionButton(
                title: "Buy",
                subtitle: "Fiat → Crypto",
                icon: "arrow.down.circle.fill",
                color: .green
            ) { showingBuy = true }

            quickActionButton(
                title: "Sell",
                subtitle: "Crypto → Fiat",
                icon: "arrow.up.circle.fill",
                color: .orange
            ) { showingSell = true }
        }
        .padding(.horizontal).padding(.top, 12).padding(.bottom, 8)
    }

    private func quickActionButton(title: String, subtitle: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.title2).foregroundColor(color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.bold()).foregroundColor(.white)
                    Text(subtitle).font(.caption2).foregroundColor(.gray)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundColor(.gray)
            }
            .padding()
            .background(color.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.15), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(TradingTab.allCases, id: \.self) { tab in
                Button(tab.rawValue) { selectedTab = tab }
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundColor(selectedTab == tab ? .white : .gray)
                    .overlay(
                        Rectangle()
                            .frame(height: 2)
                            .foregroundColor(selectedTab == tab ? .purple : .clear)
                            .padding(.horizontal, 16),
                        alignment: .bottom
                    )
            }
        }
        .background(Color.white.opacity(0.03))
        .overlay(Rectangle().frame(height: 0.5).foregroundColor(.white.opacity(0.1)), alignment: .bottom)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .swap:
            SwapView().environmentObject(walletManager)
        case .dca:
            DCAView().environmentObject(walletManager)
        case .approvals:
            TokenApprovalManagerView().environmentObject(walletManager)
        }
    }
}
