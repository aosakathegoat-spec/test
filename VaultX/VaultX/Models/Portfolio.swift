import Foundation

// MARK: - Portfolio

struct Portfolio: Identifiable, Codable {
    let id: UUID
    var userId: String
    var totalValueUSD: Decimal
    var totalCostBasis: Decimal
    var unrealizedPnL: Decimal
    var unrealizedPnLPercent: Double
    var realizedPnL: Decimal
    var dayChange: Decimal
    var dayChangePercent: Double
    var weekChange: Decimal
    var monthChange: Decimal
    var allTimeHigh: Decimal?
    var allTimeLow: Decimal?
    var allocations: [AssetAllocation]
    var chainBreakdown: [ChainAllocation]
    var performanceHistory: [PortfolioSnapshot]
    var updatedAt: Date

    var totalPnL: Decimal { unrealizedPnL + realizedPnL }
}

struct AssetAllocation: Identifiable, Codable {
    let id: UUID
    var symbol: String
    var name: String
    var chain: Chain
    var amount: Decimal
    var usdValue: Decimal
    var costBasis: Decimal
    var unrealizedPnL: Decimal
    var percentOfPortfolio: Double
    var priceChange24h: Double
    var logoURL: String?
}

struct ChainAllocation: Identifiable, Codable {
    let id: UUID
    var chain: Chain
    var usdValue: Decimal
    var percentOfPortfolio: Double
}

// MARK: - Portfolio Snapshot (for charting)

struct PortfolioSnapshot: Identifiable, Codable {
    let id: UUID
    var timestamp: Date
    var totalValueUSD: Decimal
    var totalCostBasis: Decimal
    var unrealizedPnL: Decimal
}

// MARK: - Price Alert (missing from Phantom)

struct PriceAlert: Identifiable, Codable {
    let id: UUID
    var userId: String
    var symbol: String
    var chain: Chain
    var contractAddress: String?
    var alertType: AlertType
    var targetPrice: Decimal
    var currentPrice: Decimal?
    var isActive: Bool
    var isTriggered: Bool
    var triggeredAt: Date?
    var createdAt: Date
    var repeatAlert: Bool

    enum AlertType: String, Codable {
        case priceAbove    = "price_above"
        case priceBelow    = "price_below"
        case percentChange = "percent_change"
        case volumeSpike   = "volume_spike"
        case largeTransfer = "large_transfer"
    }
}

// MARK: - DeFi Position (Phantom has no DeFi aggregation)

struct DeFiPosition: Identifiable, Codable {
    let id: UUID
    var walletAddress: String
    var chain: Chain
    var protocol_name: String
    var protocolLogoURL: String?
    var positionType: DeFiPositionType
    var tokens: [DeFiToken]
    var totalValueUSD: Decimal
    var rewards: [DeFiToken]
    var apy: Double?
    var healthFactor: Double?    // for lending positions
    var liquidationPrice: Decimal?
    var updatedAt: Date

    enum DeFiPositionType: String, Codable {
        case liquidity   = "liquidity"
        case staking     = "staking"
        case lending     = "lending"
        case borrowing   = "borrowing"
        case farming     = "farming"
        case vault       = "vault"
    }
}

struct DeFiToken: Identifiable, Codable {
    let id: UUID
    var symbol: String
    var name: String
    var amount: Decimal
    var usdValue: Decimal
    var contractAddress: String?
}

// MARK: - Tax Report (completely absent from Phantom)

struct TaxReport: Identifiable, Codable {
    let id: UUID
    var userId: String
    var taxYear: Int
    var costBasisMethod: CostBasisMethod
    var shortTermGains: Decimal
    var longTermGains: Decimal
    var totalGains: Decimal
    var totalLosses: Decimal
    var netGainLoss: Decimal
    var taxableEvents: [TaxableEvent]
    var generatedAt: Date

    enum CostBasisMethod: String, Codable, CaseIterable {
        case fifo = "FIFO"   // First In First Out
        case lifo = "LIFO"   // Last In First Out
        case hifo = "HIFO"   // Highest In First Out
        case acb  = "ACB"    // Adjusted Cost Base (Canada)
    }
}

struct TaxableEvent: Identifiable, Codable {
    let id: UUID
    var txHash: String
    var chain: Chain
    var eventType: TaxableEventType
    var asset: String
    var amount: Decimal
    var acquisitionDate: Date
    var disposalDate: Date
    var costBasisUSD: Decimal
    var proceedsUSD: Decimal
    var gainLossUSD: Decimal
    var isLongTerm: Bool
    var holdingDays: Int

    enum TaxableEventType: String, Codable {
        case sale      = "sale"
        case swap      = "swap"
        case income    = "income"     // staking rewards, airdrops
        case gift      = "gift"
        case nftSale   = "nft_sale"
    }
}
