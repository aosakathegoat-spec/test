import Foundation
import CryptoKit

// MARK: - Chain

enum Chain: String, Codable, CaseIterable, Identifiable {
    case bitcoin        = "bitcoin"
    case bitcoinTestnet = "bitcoin_testnet"
    case ethereum       = "ethereum"
    case bsc            = "bsc"
    case polygon        = "polygon"
    case solana         = "solana"
    case arbitrum       = "arbitrum"
    case optimism       = "optimism"
    case base           = "base"
    case avalanche      = "avalanche"
    case fantom         = "fantom"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bitcoin: return "Bitcoin"
        case .bitcoinTestnet: return "Bitcoin Testnet"
        case .ethereum: return "Ethereum"
        case .bsc: return "BNB Chain"
        case .polygon: return "Polygon"
        case .solana: return "Solana"
        case .arbitrum: return "Arbitrum"
        case .optimism: return "Optimism"
        case .base: return "Base"
        case .avalanche: return "Avalanche"
        case .fantom: return "Fantom"
        }
    }

    var nativeCurrency: String {
        switch self {
        case .bitcoin, .bitcoinTestnet: return "BTC"
        case .ethereum: return "ETH"
        case .bsc: return "BNB"
        case .polygon: return "MATIC"
        case .solana: return "SOL"
        case .arbitrum: return "ETH"
        case .optimism: return "ETH"
        case .base: return "ETH"
        case .avalanche: return "AVAX"
        case .fantom: return "FTM"
        }
    }

    var coinType: UInt32 {
        switch self {
        case .bitcoin, .bitcoinTestnet: return 0
        case .ethereum, .arbitrum, .optimism, .base: return 60
        case .bsc: return 60
        case .polygon: return 60
        case .solana: return 501
        case .avalanche: return 9000
        case .fantom: return 60
        }
    }

    var isEVM: Bool {
        switch self {
        case .ethereum, .bsc, .polygon, .arbitrum, .optimism, .base, .avalanche, .fantom: return true
        default: return false
        }
    }

    var symbolImage: String {
        switch self {
        case .bitcoin, .bitcoinTestnet: return "bitcoinsign.circle.fill"
        case .ethereum, .arbitrum, .optimism, .base: return "e.circle.fill"
        case .solana: return "s.circle.fill"
        default: return "dollarsign.circle.fill"
        }
    }
}

// MARK: - Wallet Type

enum WalletType: String, Codable {
    case hd           = "hd"
    case imported     = "imported"
    case watchOnly    = "watch_only"
    case multisig     = "multisig"
    case hardware     = "hardware"
}

// MARK: - Bitcoin Script Types (Phantom doesn't support native BTC at all)

enum BitcoinScriptType: String, Codable, CaseIterable {
    case legacy     = "P2PKH"    // 1... addresses
    case segwitP2SH = "P2SH-P2WPKH"  // 3... addresses
    case nativeSegwit = "P2WPKH"     // bc1q... addresses
    case taproot    = "P2TR"         // bc1p... addresses — Ordinals/BRC-20

    var derivationPath: String {
        switch self {
        case .legacy: return "m/44'/0'/0'"
        case .segwitP2SH: return "m/49'/0'/0'"
        case .nativeSegwit: return "m/84'/0'/0'"
        case .taproot: return "m/86'/0'/0'"
        }
    }

    var displayName: String {
        switch self {
        case .legacy: return "Legacy (P2PKH)"
        case .segwitP2SH: return "SegWit Compatible"
        case .nativeSegwit: return "Native SegWit"
        case .taproot: return "Taproot (Ordinals/BRC-20)"
        }
    }
}

// MARK: - Wallet Model

struct Wallet: Identifiable, Codable {
    let id: UUID
    var name: String
    var chain: Chain
    var walletType: WalletType
    var address: String
    var derivationPath: String?
    var isPrimary: Bool
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    // Bitcoin-specific
    var bitcoinScriptType: BitcoinScriptType?
    var xpub: String?

    // Multi-sig metadata
    var multiSigConfig: MultiSigConfig?

    // Hardware wallet
    var hardwareWalletId: String?

    var balance: WalletBalance?

    init(
        id: UUID = UUID(),
        name: String,
        chain: Chain,
        walletType: WalletType = .hd,
        address: String,
        derivationPath: String? = nil,
        isPrimary: Bool = false,
        bitcoinScriptType: BitcoinScriptType? = nil
    ) {
        self.id = id
        self.name = name
        self.chain = chain
        self.walletType = walletType
        self.address = address
        self.derivationPath = derivationPath
        self.isPrimary = isPrimary
        self.isArchived = false
        self.createdAt = Date()
        self.updatedAt = Date()
        self.bitcoinScriptType = bitcoinScriptType
    }

    var shortAddress: String {
        guard address.count > 12 else { return address }
        return "\(address.prefix(6))...\(address.suffix(4))"
    }
}

// MARK: - Multi-Sig Config

struct MultiSigConfig: Codable {
    var requiredSignatures: Int   // M in M-of-N
    var totalSigners: Int         // N in M-of-N
    var signers: [MultiSigSigner]
    var pendingTransactions: [PendingMultiSigTx]

    var threshold: String { "\(requiredSignatures) of \(totalSigners)" }
}

struct MultiSigSigner: Identifiable, Codable {
    let id: UUID
    var label: String
    var publicKey: String
    var walletAddress: String?
    var userId: String?
    var signerIndex: Int
}

// MARK: - Wallet Balance

struct WalletBalance: Codable {
    var nativeAmount: Decimal
    var nativeSymbol: String
    var usdValue: Decimal
    var tokens: [TokenBalance]
    var nfts: [NFTAsset]
    var updatedAt: Date
}

struct TokenBalance: Identifiable, Codable {
    let id: UUID
    var contractAddress: String
    var symbol: String
    var name: String
    var decimals: Int
    var balance: Decimal
    var usdValue: Decimal
    var logoURL: String?
    var priceChange24h: Double?
    // BRC-20 token flag (Bitcoin)
    var isBRC20: Bool = false
}

struct NFTAsset: Identifiable, Codable {
    let id: UUID
    var contractAddress: String
    var tokenId: String
    var name: String
    var description: String?
    var imageURL: String?
    var collectionName: String?
    var floorPriceUSD: Decimal?
    var isOrdinal: Bool = false  // Bitcoin Ordinals support
    var inscriptionId: String?
}
