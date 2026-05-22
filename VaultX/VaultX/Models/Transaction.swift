import Foundation

enum TransactionType: String, Codable {
    case send     = "send"
    case receive  = "receive"
    case swap     = "swap"
    case approve  = "approve"   // ERC-20 approval
    case stake    = "stake"
    case unstake  = "unstake"
    case bridge   = "bridge"
    case nftMint  = "nft_mint"
    case nftSale  = "nft_sale"
}

enum TransactionStatus: String, Codable {
    case pending   = "pending"
    case confirmed = "confirmed"
    case failed    = "failed"
    case dropped   = "dropped"
}

struct Transaction: Identifiable, Codable {
    let id: UUID
    var walletId: UUID
    var chain: Chain
    var txHash: String
    var type: TransactionType
    var status: TransactionStatus

    var fromAddress: String
    var toAddress: String
    var amount: Decimal
    var symbol: String
    var decimals: Int
    var usdValueAtTime: Decimal?
    var currentUSDValue: Decimal?

    // Gas / Fees
    var gasFeeNative: Decimal?
    var gasFeeUSD: Decimal?
    var gasPrice: Decimal?
    var gasUsed: UInt64?

    // EVM specific
    var blockNumber: UInt64?
    var nonce: UInt64?
    var contractAddress: String?
    var inputData: String?

    // Bitcoin specific
    var bitcoinFeeRate: Decimal?  // sat/vByte
    var confirmations: Int?
    var utxos: [BitcoinUTXO]?

    // Swap specific
    var swapFromToken: String?
    var swapToToken: String?
    var swapFromAmount: Decimal?
    var swapToAmount: Decimal?

    var timestamp: Date
    var confirmedAt: Date?

    // Tax tracking — built-in, Phantom has no tax support
    var costBasis: Decimal?
    var realizedGainLoss: Decimal?
    var isLongTermGain: Bool?
    var taxLotId: UUID?

    // Security flags
    var isSuspicious: Bool = false
    var suspiciousReasons: [String] = []
    var phishingRisk: PhishingRisk = .none

    var isSend: Bool { type == .send }
    var isReceive: Bool { type == .receive }
}

// MARK: - Bitcoin UTXO

struct BitcoinUTXO: Codable {
    var txid: String
    var vout: UInt32
    var value: Decimal       // in satoshis
    var scriptPubKey: String
    var address: String?
    var confirmations: Int
    var isLocked: Bool = false   // coin control — lock specific UTXOs
}

// MARK: - Multi-Sig Pending TX

struct PendingMultiSigTx: Identifiable, Codable {
    let id: UUID
    var multisigWalletId: UUID
    var proposerId: String
    var toAddress: String
    var amount: Decimal
    var symbol: String
    var chain: Chain
    var rawTxHex: String
    var txHash: String?
    var signatures: [MultiSigSignature]
    var requiredSignatures: Int
    var status: PendingTxStatus
    var note: String?
    var createdAt: Date
    var expiresAt: Date?

    var isReady: Bool { signatures.count >= requiredSignatures }
    var signatureCount: String { "\(signatures.count)/\(requiredSignatures)" }

    enum PendingTxStatus: String, Codable {
        case collecting = "collecting"
        case ready      = "ready"
        case broadcast  = "broadcast"
        case confirmed  = "confirmed"
        case expired    = "expired"
        case cancelled  = "cancelled"
    }
}

struct MultiSigSignature: Identifiable, Codable {
    let id: UUID
    var signerId: UUID
    var signerAddress: String
    var signature: String
    var signedAt: Date
}

// MARK: - Phishing Risk

enum PhishingRisk: String, Codable {
    case none    = "none"
    case low     = "low"
    case medium  = "medium"
    case high    = "high"
    case blocked = "blocked"

    var color: String {
        switch self {
        case .none: return "green"
        case .low: return "yellow"
        case .medium: return "orange"
        case .high, .blocked: return "red"
        }
    }
}
