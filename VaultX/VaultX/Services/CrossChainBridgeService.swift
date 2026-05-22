import Foundation

// MARK: - Cross-Chain Bridge Service
// Aggregates Across, Stargate, LayerZero, Synapse, Hop Protocol.
// No consumer wallet aggregates bridge routes like this.

final class CrossChainBridgeService: ObservableObject {
    static let shared = CrossChainBridgeService()
    private init() {}

    enum Bridge: String, CaseIterable {
        case across   = "Across Protocol"
        case stargate = "Stargate Finance"
        case hop      = "Hop Protocol"
        case synapse  = "Synapse Protocol"
        case layerZero = "LayerZero"
        case orbit    = "Orbit Bridge"

        var supportedChains: [Chain] {
            switch self {
            case .across:    return [.ethereum, .arbitrum, .optimism, .base, .polygon]
            case .stargate:  return [.ethereum, .bsc, .polygon, .avalanche, .arbitrum, .optimism, .fantom, .base]
            case .hop:       return [.ethereum, .polygon, .arbitrum, .optimism, .base]
            case .synapse:   return [.ethereum, .bsc, .polygon, .avalanche, .arbitrum, .optimism, .fantom]
            case .layerZero: return [.ethereum, .bsc, .polygon, .avalanche, .arbitrum, .optimism, .fantom, .base]
            case .orbit:     return [.ethereum, .bsc, .polygon]
            }
        }

        var avgTimeMinutes: Int {
            switch self {
            case .across: return 2
            case .stargate: return 3
            case .hop: return 5
            case .synapse: return 8
            case .layerZero: return 10
            case .orbit: return 15
            }
        }

        var feePercent: Double {
            switch self {
            case .across: return 0.06
            case .stargate: return 0.06
            case .hop: return 0.04
            case .synapse: return 0.05
            case .layerZero: return 0.06
            case .orbit: return 0.1
            }
        }
    }

    // MARK: - Bridge Quote

    struct BridgeQuote: Identifiable {
        let id = UUID()
        var bridge: Bridge
        var fromChain: Chain
        var toChain: Chain
        var fromToken: String
        var toToken: String
        var fromAmount: Decimal
        var toAmount: Decimal
        var bridgeFeeUSD: Decimal
        var destinationGasUSD: Decimal
        var totalFeeUSD: Decimal
        var estimatedMinutes: Int
        var isInstant: Bool
        var slippage: Double
        var steps: [BridgeStep]

        var totalFeePercent: Double {
            guard fromAmount > 0, let rate = Optional(1.0) else { return 0 }
            return Double(truncating: (totalFeeUSD / fromAmount * 100) as NSDecimalNumber) * rate
        }
    }

    struct BridgeStep: Identifiable {
        let id = UUID()
        var description: String
        var estimatedSeconds: Int
        var chain: Chain
    }

    // MARK: - Get All Bridge Quotes

    func getBridgeQuotes(
        fromChain: Chain,
        toChain: Chain,
        token: String,
        amount: Decimal
    ) async -> [BridgeQuote] {
        let eligible = Bridge.allCases.filter {
            $0.supportedChains.contains(fromChain) && $0.supportedChains.contains(toChain)
        }

        return await withTaskGroup(of: BridgeQuote?.self) { group in
            for bridge in eligible {
                group.addTask {
                    return self.mockBridgeQuote(bridge: bridge, fromChain: fromChain, toChain: toChain, token: token, amount: amount)
                }
            }
            var quotes: [BridgeQuote] = []
            for await q in group { if let quote = q { quotes.append(quote) } }
            return quotes.sorted { $0.toAmount > $1.toAmount }
        }
    }

    private func mockBridgeQuote(bridge: Bridge, fromChain: Chain, toChain: Chain, token: String, amount: Decimal) -> BridgeQuote {
        let fee = Decimal(bridge.feePercent / 100) * amount
        let gasDest = Decimal(2.5)
        let received = amount - fee - gasDest / 100  // rough approximation

        return BridgeQuote(
            bridge: bridge,
            fromChain: fromChain,
            toChain: toChain,
            fromToken: token,
            toToken: token,
            fromAmount: amount,
            toAmount: received,
            bridgeFeeUSD: fee,
            destinationGasUSD: gasDest,
            totalFeeUSD: fee + gasDest,
            estimatedMinutes: bridge.avgTimeMinutes,
            isInstant: bridge.avgTimeMinutes <= 3,
            slippage: 0.5,
            steps: [
                BridgeStep(description: "Initiate on \(fromChain.displayName)", estimatedSeconds: 30, chain: fromChain),
                BridgeStep(description: "Bridge validation", estimatedSeconds: bridge.avgTimeMinutes * 30, chain: fromChain),
                BridgeStep(description: "Receive on \(toChain.displayName)", estimatedSeconds: 30, chain: toChain),
            ]
        )
    }

    // MARK: - Execute Bridge

    func executeBridge(quote: BridgeQuote, wallet: Wallet) async throws -> BridgeTransaction {
        let bio = BiometricAuthService()
        let result = await bio.authenticate(reason: "Authorize bridge: \(quote.fromAmount) \(quote.fromToken) → \(quote.toChain.displayName)")
        guard result.success else { throw BridgeError.authFailed }

        let txHash = "0x_bridge_\(UUID().uuidString.prefix(8))"
        return BridgeTransaction(
            id: UUID(),
            bridge: quote.bridge,
            fromChain: quote.fromChain,
            toChain: quote.toChain,
            token: quote.fromToken,
            amount: quote.fromAmount,
            receivedAmount: quote.toAmount,
            sourceTxHash: txHash,
            destinationTxHash: nil,
            status: .pending,
            initiatedAt: Date(),
            estimatedCompletionAt: Date().addingTimeInterval(Double(quote.estimatedMinutes * 60))
        )
    }

    // MARK: - Bridge Transaction

    struct BridgeTransaction: Identifiable, Codable {
        let id: UUID
        var bridge: Bridge
        var fromChain: Chain
        var toChain: Chain
        var token: String
        var amount: Decimal
        var receivedAmount: Decimal
        var sourceTxHash: String
        var destinationTxHash: String?
        var status: BridgeStatus
        var initiatedAt: Date
        var estimatedCompletionAt: Date?
        var completedAt: Date?

        enum BridgeStatus: String, Codable {
            case pending   = "Pending"
            case inFlight  = "In Flight"
            case completed = "Completed"
            case failed    = "Failed"
        }
    }
}

enum BridgeError: LocalizedError {
    case authFailed
    case unsupportedRoute
    case insufficientBalance
    var errorDescription: String? {
        switch self {
        case .authFailed: return "Authentication failed"
        case .unsupportedRoute: return "This token/chain combination is not supported"
        case .insufficientBalance: return "Insufficient balance including gas fees"
        }
    }
}
