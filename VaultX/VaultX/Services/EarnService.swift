import Foundation

// MARK: - Earn Service: Staking, Lending, Yield Farming
// Phantom has basic staking. VaultX adds multi-protocol yield comparison,
// liquid staking, lending positions, and vault strategies.

final class EarnService: ObservableObject {
    static let shared = EarnService()
    private init() {}

    // MARK: - Earn Opportunity

    enum EarnCategory: String, CaseIterable {
        case staking     = "Staking"
        case liquidStake = "Liquid Staking"
        case lending     = "Lending"
        case lpFarming   = "LP Farming"
        case vault       = "Yield Vault"
        case savings     = "Savings"
    }

    struct EarnOpportunity: Identifiable {
        let id: UUID
        var protocol_name: String
        var protocolLogoURL: String?
        var category: EarnCategory
        var asset: String
        var chain: Chain
        var apy: Double            // Base APY
        var apyMax: Double         // Max APY with boosts
        var tvlUSD: Decimal        // Total value locked
        var risk: RiskLevel
        var lockupPeriod: LockupPeriod
        var minDeposit: Decimal
        var rewards: [String]      // Reward tokens
        var isAudited: Bool
        var auditors: [String]
        var description: String
        var contractAddress: String?

        enum RiskLevel: String, CaseIterable {
            case low    = "Low"
            case medium = "Medium"
            case high   = "High"

            var color: String {
                switch self { case .low: return "green"; case .medium: return "yellow"; case .high: return "red" }
            }
        }

        enum LockupPeriod: String, Codable {
            case none       = "No Lockup"
            case sevenDays  = "7 Days"
            case thirtyDays = "30 Days"
            case variable   = "Variable"
        }

        var apyDisplay: String {
            apy == apyMax
                ? String(format: "%.1f%%", apy)
                : String(format: "%.1f - %.1f%%", apy, apyMax)
        }
    }

    // MARK: - Fetch Opportunities

    func fetchOpportunities(chain: Chain? = nil, asset: String? = nil) async -> [EarnOpportunity] {
        var all = hardcodedOpportunities()
        if let chain { all = all.filter { $0.chain == chain } }
        if let asset { all = all.filter { $0.asset == asset } }
        return all.sorted { $0.apy > $1.apy }
    }

    private func hardcodedOpportunities() -> [EarnOpportunity] {
        [
            // Ethereum Staking
            EarnOpportunity(
                id: UUID(), protocol_name: "Lido Finance", category: .liquidStake,
                asset: "ETH", chain: .ethereum, apy: 3.9, apyMax: 3.9, tvlUSD: 30_000_000_000,
                risk: .low, lockupPeriod: .none, minDeposit: 0.01, rewards: ["stETH"],
                isAudited: true, auditors: ["Sigma Prime", "Quantstamp"],
                description: "Stake ETH and receive stETH, a liquid token earning daily staking rewards",
                contractAddress: "0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84"
            ),
            EarnOpportunity(
                id: UUID(), protocol_name: "Rocket Pool", category: .liquidStake,
                asset: "ETH", chain: .ethereum, apy: 3.6, apyMax: 3.6, tvlUSD: 4_500_000_000,
                risk: .low, lockupPeriod: .none, minDeposit: 0.01, rewards: ["rETH"],
                isAudited: true, auditors: ["Sigma Prime", "Trail of Bits"],
                description: "Decentralized ETH staking protocol. No minimum for liquid staking.",
                contractAddress: "0xDD3f50F8A6CafbE9b31a427582963f465E745AF8"
            ),
            // AAVE Lending
            EarnOpportunity(
                id: UUID(), protocol_name: "Aave V3", category: .lending,
                asset: "USDC", chain: .ethereum, apy: 4.8, apyMax: 7.2, tvlUSD: 12_000_000_000,
                risk: .low, lockupPeriod: .none, minDeposit: 1, rewards: ["USDC", "AAVE"],
                isAudited: true, auditors: ["OpenZeppelin", "Trail of Bits"],
                description: "Supply USDC to earn variable lending interest + AAVE rewards",
                contractAddress: "0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2"
            ),
            // Compound
            EarnOpportunity(
                id: UUID(), protocol_name: "Compound V3", category: .lending,
                asset: "USDC", chain: .ethereum, apy: 4.2, apyMax: 5.1, tvlUSD: 2_800_000_000,
                risk: .low, lockupPeriod: .none, minDeposit: 1, rewards: ["USDC", "COMP"],
                isAudited: true, auditors: ["OpenZeppelin"],
                description: "Algorithmic money market. Earn interest on USDC deposits.",
                contractAddress: "0xc3d688B66703497DAA19211EEdff47f25384cdc3"
            ),
            // Uniswap V3 LP
            EarnOpportunity(
                id: UUID(), protocol_name: "Uniswap V3", category: .lpFarming,
                asset: "ETH/USDC", chain: .ethereum, apy: 12.0, apyMax: 40.0, tvlUSD: 800_000_000,
                risk: .medium, lockupPeriod: .none, minDeposit: 100, rewards: ["ETH", "USDC", "UNI"],
                isAudited: true, auditors: ["Trail of Bits"],
                description: "Provide concentrated liquidity. Higher fees but requires active management.",
                contractAddress: "0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640"
            ),
            // Curve stablecoin pool
            EarnOpportunity(
                id: UUID(), protocol_name: "Curve Finance", category: .lpFarming,
                asset: "3pool (USDC/USDT/DAI)", chain: .ethereum, apy: 2.1, apyMax: 5.8, tvlUSD: 600_000_000,
                risk: .low, lockupPeriod: .none, minDeposit: 1, rewards: ["CRV", "CVX"],
                isAudited: true, auditors: ["Trail of Bits", "Chainsecurity"],
                description: "Stablecoin LP with low impermanent loss risk",
                contractAddress: "0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7"
            ),
            // Solana staking
            EarnOpportunity(
                id: UUID(), protocol_name: "Marinade Finance", category: .liquidStake,
                asset: "SOL", chain: .solana, apy: 7.2, apyMax: 7.2, tvlUSD: 1_500_000_000,
                risk: .low, lockupPeriod: .none, minDeposit: 0.001, rewards: ["mSOL"],
                isAudited: true, auditors: ["Neodyme", "Kudelski Security"],
                description: "Liquid staking for Solana. Receive mSOL and use in DeFi.",
                contractAddress: nil
            ),
            // Yearn Vault
            EarnOpportunity(
                id: UUID(), protocol_name: "Yearn Finance", category: .vault,
                asset: "USDC", chain: .ethereum, apy: 6.8, apyMax: 12.0, tvlUSD: 400_000_000,
                risk: .medium, lockupPeriod: .none, minDeposit: 100, rewards: ["USDC", "YFI"],
                isAudited: true, auditors: ["Chainsecurity"],
                description: "Auto-compounding vault that optimizes yield across protocols",
                contractAddress: "0xa354F35829Ae975e850e23e9615b11Da1B3dC4DE"
            ),
        ]
    }

    // MARK: - Active Positions

    @Published var activePositions: [ActiveEarnPosition] = []

    struct ActiveEarnPosition: Identifiable, Codable {
        let id: UUID
        var opportunityId: UUID
        var protocolName: String
        var asset: String
        var chain: Chain
        var depositedAmount: Decimal
        var currentValue: Decimal
        var earnedRewards: Decimal
        var apy: Double
        var depositDate: Date
        var category: String

        var unrealizedGain: Decimal { currentValue - depositedAmount }
        var roiPercent: Double {
            guard depositedAmount > 0 else { return 0 }
            return Double(truncating: (unrealizedGain / depositedAmount * 100) as NSDecimalNumber)
        }
    }

    // MARK: - Deposit / Withdraw

    func deposit(opportunity: EarnOpportunity, amount: Decimal, wallet: Wallet) async throws -> String {
        let bio = BiometricAuthService()
        let result = await bio.authenticate(reason: "Authorize deposit of \(amount) \(opportunity.asset) to \(opportunity.protocol_name)")
        guard result.success else { throw EarnError.authFailed }

        let position = ActiveEarnPosition(
            id: UUID(),
            opportunityId: opportunity.id,
            protocolName: opportunity.protocol_name,
            asset: opportunity.asset,
            chain: opportunity.chain,
            depositedAmount: amount,
            currentValue: amount,
            earnedRewards: 0,
            apy: opportunity.apy,
            depositDate: Date(),
            category: opportunity.category.rawValue
        )

        await MainActor.run { activePositions.append(position) }
        savePositions()
        return "0x_deposit_tx_\(UUID().uuidString.prefix(8))"
    }

    func withdraw(position: ActiveEarnPosition, amount: Decimal, wallet: Wallet) async throws -> String {
        let bio = BiometricAuthService()
        let result = await bio.authenticate(reason: "Authorize withdrawal of \(amount) \(position.asset) from \(position.protocolName)")
        guard result.success else { throw EarnError.authFailed }

        await MainActor.run {
            if let i = activePositions.firstIndex(where: { $0.id == position.id }) {
                activePositions[i].currentValue -= amount
                if activePositions[i].currentValue <= 0 {
                    activePositions.remove(at: i)
                }
            }
        }
        savePositions()
        return "0x_withdraw_tx_\(UUID().uuidString.prefix(8))"
    }

    // MARK: - Yield Calculator

    func calculateProjectedEarnings(amount: Decimal, apy: Double, days: Int) -> Decimal {
        let dailyRate = apy / 365 / 100
        let compounded = Decimal(pow(1 + dailyRate, Double(days))) * amount
        return compounded - amount
    }

    private func savePositions() {
        if let data = try? JSONEncoder().encode(activePositions) {
            UserDefaults.standard.set(data, forKey: "earnPositions")
        }
    }

    func loadPositions() {
        guard let data = UserDefaults.standard.data(forKey: "earnPositions"),
              let positions = try? JSONDecoder().decode([ActiveEarnPosition].self, from: data)
        else { return }
        activePositions = positions
    }
}

enum EarnError: LocalizedError {
    case authFailed
    case insufficientBalance
    case belowMinimum
    case lockupActive

    var errorDescription: String? {
        switch self {
        case .authFailed: return "Authentication failed"
        case .insufficientBalance: return "Insufficient balance"
        case .belowMinimum: return "Amount below minimum deposit"
        case .lockupActive: return "Funds are in lockup period"
        }
    }
}
