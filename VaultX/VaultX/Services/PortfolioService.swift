import Foundation
import Combine

// MARK: - Portfolio Service
// Phantom has basic portfolio view. VaultX adds P&L, Sharpe ratio, DeFi positions,
// advanced analytics, and cross-chain portfolio aggregation.

final class PortfolioService: ObservableObject {
    static let shared = PortfolioService()

    @Published var portfolio: Portfolio?
    @Published var defiPositions: [DeFiPosition] = []
    @Published var priceAlerts: [PriceAlert] = []
    @Published var isLoading = false

    private let networkService = NetworkService.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {}

    // MARK: - Portfolio Aggregation

    func refreshPortfolio(wallets: [Wallet]) async {
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }

        var allocations: [AssetAllocation] = []
        var chainBreakdown: [Chain: Decimal] = [:]
        var totalValue: Decimal = 0
        var totalCostBasis: Decimal = 0

        // Aggregate all wallets
        for wallet in wallets where !wallet.isArchived {
            guard let balance = wallet.balance else { continue }

            // Native asset
            let nativeAlloc = AssetAllocation(
                id: UUID(),
                symbol: wallet.chain.nativeCurrency,
                name: wallet.chain.nativeCurrency,
                chain: wallet.chain,
                amount: balance.nativeAmount,
                usdValue: balance.usdValue,
                costBasis: 0,   // From transaction history
                unrealizedPnL: 0,
                percentOfPortfolio: 0,
                priceChange24h: 0
            )
            allocations.append(nativeAlloc)
            totalValue += balance.usdValue
            chainBreakdown[wallet.chain, default: 0] += balance.usdValue

            // Token balances
            for token in balance.tokens {
                allocations.append(AssetAllocation(
                    id: UUID(),
                    symbol: token.symbol,
                    name: token.name,
                    chain: wallet.chain,
                    amount: token.balance,
                    usdValue: token.usdValue,
                    costBasis: 0,
                    unrealizedPnL: 0,
                    percentOfPortfolio: 0,
                    priceChange24h: token.priceChange24h ?? 0
                ))
                totalValue += token.usdValue
                chainBreakdown[wallet.chain, default: 0] += token.usdValue
            }
        }

        // Calculate portfolio percentages
        if totalValue > 0 {
            for i in allocations.indices {
                allocations[i].percentOfPortfolio = Double(truncating: (allocations[i].usdValue / totalValue * 100) as NSDecimalNumber)
            }
        }

        // Build chain breakdown
        let chainAllocs = chainBreakdown.map { (chain, value) in
            ChainAllocation(
                id: UUID(),
                chain: chain,
                usdValue: value,
                percentOfPortfolio: totalValue > 0 ? Double(truncating: (value / totalValue * 100) as NSDecimalNumber) : 0
            )
        }

        // Snapshot for history
        let snapshot = PortfolioSnapshot(
            id: UUID(),
            timestamp: Date(),
            totalValueUSD: totalValue,
            totalCostBasis: totalCostBasis,
            unrealizedPnL: totalValue - totalCostBasis
        )

        await MainActor.run {
            self.portfolio = Portfolio(
                id: UUID(),
                userId: "",
                totalValueUSD: totalValue,
                totalCostBasis: totalCostBasis,
                unrealizedPnL: totalValue - totalCostBasis,
                unrealizedPnLPercent: totalCostBasis > 0
                    ? Double(truncating: ((totalValue - totalCostBasis) / totalCostBasis * 100) as NSDecimalNumber)
                    : 0,
                realizedPnL: 0,
                dayChange: 0,
                dayChangePercent: 0,
                weekChange: 0,
                monthChange: 0,
                allocations: allocations.sorted { $0.usdValue > $1.usdValue },
                chainBreakdown: chainAllocs,
                performanceHistory: [snapshot],
                updatedAt: Date()
            )
        }

        // Fetch DeFi positions
        await refreshDeFiPositions(wallets: wallets)
    }

    // MARK: - DeFi Position Aggregation (Phantom has none)

    func refreshDeFiPositions(wallets: [Wallet]) async {
        let evmWallets = wallets.filter { $0.chain.isEVM && !$0.isArchived }

        var positions: [DeFiPosition] = []
        for wallet in evmWallets {
            let walletPositions = await fetchDeFiPositions(address: wallet.address, chain: wallet.chain)
            positions.append(contentsOf: walletPositions)
        }

        await MainActor.run {
            self.defiPositions = positions.sorted { $0.totalValueUSD > $1.totalValueUSD }
        }
    }

    private func fetchDeFiPositions(address: String, chain: Chain) async -> [DeFiPosition] {
        // In production: call DeBank API or Zapper API for DeFi position aggregation
        return []
    }

    // MARK: - Analytics

    func calculateSharpeRatio(snapshots: [PortfolioSnapshot], riskFreeRate: Double = 0.05) -> Double? {
        guard snapshots.count >= 2 else { return nil }

        let returns = zip(snapshots.dropFirst(), snapshots).map { (curr, prev) -> Double in
            guard prev.totalValueUSD > 0 else { return 0 }
            return Double(truncating: ((curr.totalValueUSD - prev.totalValueUSD) / prev.totalValueUSD) as NSDecimalNumber)
        }

        let avgReturn = returns.reduce(0, +) / Double(returns.count)
        let variance = returns.map { pow($0 - avgReturn, 2) }.reduce(0, +) / Double(returns.count)
        let stdDev = sqrt(variance)

        guard stdDev > 0 else { return nil }
        return (avgReturn - riskFreeRate / 365) / stdDev * sqrt(365)
    }

    func calculateMaxDrawdown(snapshots: [PortfolioSnapshot]) -> Double {
        guard !snapshots.isEmpty else { return 0 }

        var maxDrawdown = 0.0
        var peak = snapshots[0].totalValueUSD

        for snapshot in snapshots {
            if snapshot.totalValueUSD > peak {
                peak = snapshot.totalValueUSD
            }
            if peak > 0 {
                let drawdown = Double(truncating: ((peak - snapshot.totalValueUSD) / peak) as NSDecimalNumber)
                maxDrawdown = max(maxDrawdown, drawdown)
            }
        }

        return maxDrawdown
    }

    func calculateROI(costBasis: Decimal, currentValue: Decimal) -> Double {
        guard costBasis > 0 else { return 0 }
        return Double(truncating: ((currentValue - costBasis) / costBasis * 100) as NSDecimalNumber)
    }

    // MARK: - Price Alerts (missing from Phantom)

    func createPriceAlert(
        symbol: String,
        chain: Chain,
        alertType: PriceAlert.AlertType,
        targetPrice: Decimal,
        repeat: Bool = false
    ) -> PriceAlert {
        let alert = PriceAlert(
            id: UUID(),
            userId: "",
            symbol: symbol,
            chain: chain,
            alertType: alertType,
            targetPrice: targetPrice,
            isActive: true,
            isTriggered: false,
            createdAt: Date(),
            repeatAlert: `repeat`
        )
        priceAlerts.append(alert)
        savePriceAlerts()
        return alert
    }

    func checkPriceAlerts(prices: [String: Decimal]) {
        for i in priceAlerts.indices {
            guard priceAlerts[i].isActive, !priceAlerts[i].isTriggered else { continue }
            let alert = priceAlerts[i]
            guard let currentPrice = prices[alert.symbol] else { continue }

            let triggered: Bool
            switch alert.alertType {
            case .priceAbove: triggered = currentPrice >= alert.targetPrice
            case .priceBelow: triggered = currentPrice <= alert.targetPrice
            case .percentChange, .volumeSpike, .largeTransfer: triggered = false
            }

            if triggered {
                priceAlerts[i].isTriggered = !alert.repeatAlert
                priceAlerts[i].triggeredAt = Date()
                priceAlerts[i].currentPrice = currentPrice
                NotificationService.shared.sendPriceAlert(alert: priceAlerts[i])
            }
        }
        savePriceAlerts()
    }

    private func savePriceAlerts() {
        if let data = try? JSONEncoder().encode(priceAlerts) {
            UserDefaults.standard.set(data, forKey: "priceAlerts")
        }
    }

    func loadPriceAlerts() {
        guard let data = UserDefaults.standard.data(forKey: "priceAlerts"),
              let alerts = try? JSONDecoder().decode([PriceAlert].self, from: data) else { return }
        priceAlerts = alerts
    }
}
