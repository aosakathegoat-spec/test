import Foundation
import Combine
import CryptoKit

@MainActor
final class WalletManager: ObservableObject {
    @Published var wallets: [Wallet] = []
    @Published var selectedWallet: Wallet?
    @Published var isLoading = false
    @Published var error: WalletError?

    private let keychain = KeychainService.shared
    private let encryption = EncryptionService.shared
    private let hdWalletService = HDWalletService()
    private let networkService = NetworkService.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - HD Wallet Creation

    /// Creates a new HD wallet with a fresh BIP-39 mnemonic
    func createHDWallet(
        name: String,
        chains: [Chain],
        password: String,
        wordCount: MnemonicWordCount = .twentyFour
    ) async throws -> (wallet: Wallet, mnemonic: String) {
        isLoading = true
        defer { isLoading = false }

        // 1. Generate entropy and mnemonic
        let mnemonic = try hdWalletService.generateMnemonic(wordCount: wordCount)

        // 2. Encrypt and store mnemonic in Keychain
        let hdWalletId = UUID().uuidString
        let encryptedMnemonic = try encryption.encryptMnemonic(mnemonic, password: password)
        try keychain.saveMnemonic(encryptedMnemonic, hdWalletId: hdWalletId)

        // 3. Derive wallet addresses for each requested chain
        var createdWallets: [Wallet] = []
        for chain in chains {
            let derived = try hdWalletService.deriveWallet(mnemonic: mnemonic, chain: chain)
            var wallet = Wallet(
                name: "\(name) (\(chain.displayName))",
                chain: chain,
                walletType: .hd,
                address: derived.address,
                derivationPath: derived.path,
                isPrimary: chain == chains.first
            )

            // For Bitcoin, create all four script types
            if chain == .bitcoin {
                for scriptType in BitcoinScriptType.allCases {
                    let btcWallet = try hdWalletService.deriveBitcoinWallet(
                        mnemonic: mnemonic,
                        scriptType: scriptType
                    )
                    var bw = Wallet(
                        name: "\(name) BTC (\(scriptType.displayName))",
                        chain: .bitcoin,
                        walletType: .hd,
                        address: btcWallet.address,
                        derivationPath: btcWallet.path,
                        isPrimary: scriptType == .nativeSegwit,
                        bitcoinScriptType: scriptType
                    )
                    bw.xpub = btcWallet.xpub
                    createdWallets.append(bw)
                }
                continue
            }

            // Store encrypted private key
            let encryptedKey = try encryption.encryptPrivateKey(derived.privateKeyHex, password: password)
            try keychain.saveEncryptedPrivateKey(encryptedKey, walletId: wallet.id.uuidString)

            createdWallets.append(wallet)
        }

        wallets.append(contentsOf: createdWallets)
        persistWallets()

        return (createdWallets.first!, mnemonic)
    }

    // MARK: - Import Wallet

    func importFromMnemonic(
        name: String,
        mnemonic: String,
        chains: [Chain],
        password: String
    ) async throws -> [Wallet] {
        isLoading = true
        defer { isLoading = false }

        guard hdWalletService.validateMnemonic(mnemonic) else {
            throw WalletError.invalidMnemonic
        }

        var imported: [Wallet] = []
        let hdWalletId = UUID().uuidString
        let encryptedMnemonic = try encryption.encryptMnemonic(mnemonic, password: password)
        try keychain.saveMnemonic(encryptedMnemonic, hdWalletId: hdWalletId)

        for chain in chains {
            let derived = try hdWalletService.deriveWallet(mnemonic: mnemonic, chain: chain)
            let wallet = Wallet(
                name: "\(name) (\(chain.displayName))",
                chain: chain,
                walletType: .imported,
                address: derived.address,
                derivationPath: derived.path
            )
            let encryptedKey = try encryption.encryptPrivateKey(derived.privateKeyHex, password: password)
            try keychain.saveEncryptedPrivateKey(encryptedKey, walletId: wallet.id.uuidString)
            imported.append(wallet)
        }

        wallets.append(contentsOf: imported)
        persistWallets()
        return imported
    }

    func importFromPrivateKey(
        name: String,
        privateKeyHex: String,
        chain: Chain,
        password: String
    ) async throws -> Wallet {
        isLoading = true
        defer { isLoading = false }

        let address = try hdWalletService.addressFromPrivateKey(privateKeyHex, chain: chain)
        let wallet = Wallet(
            name: name,
            chain: chain,
            walletType: .imported,
            address: address
        )
        let encryptedKey = try encryption.encryptPrivateKey(privateKeyHex, password: password)
        try keychain.saveEncryptedPrivateKey(encryptedKey, walletId: wallet.id.uuidString)

        wallets.append(wallet)
        persistWallets()
        return wallet
    }

    // MARK: - Watch-Only Wallet

    func addWatchOnlyWallet(name: String, address: String, chain: Chain) -> Wallet {
        let wallet = Wallet(
            name: name,
            chain: chain,
            walletType: .watchOnly,
            address: address
        )
        wallets.append(wallet)
        persistWallets()
        return wallet
    }

    // MARK: - Multi-Sig Wallet Creation (Phantom has very limited multi-sig)

    func createMultiSigWallet(
        name: String,
        chain: Chain,
        requiredSignatures: Int,
        signers: [MultiSigSigner]
    ) async throws -> Wallet {
        isLoading = true
        defer { isLoading = false }

        guard requiredSignatures <= signers.count else {
            throw WalletError.invalidMultiSigConfig
        }

        let address = try await networkService.deployMultiSigWallet(
            chain: chain,
            signers: signers.map { $0.publicKey },
            required: requiredSignatures
        )

        var wallet = Wallet(
            name: name,
            chain: chain,
            walletType: .multisig,
            address: address
        )

        wallet.multiSigConfig = MultiSigConfig(
            requiredSignatures: requiredSignatures,
            totalSigners: signers.count,
            signers: signers,
            pendingTransactions: []
        )

        wallets.append(wallet)
        persistWallets()
        return wallet
    }

    // MARK: - Balance Refresh

    func refreshBalances() async {
        await withTaskGroup(of: Void.self) { group in
            for wallet in wallets where !wallet.isArchived {
                group.addTask {
                    await self.refreshBalance(for: wallet)
                }
            }
        }
    }

    private func refreshBalance(for wallet: Wallet) async {
        guard let balance = try? await networkService.fetchBalance(wallet: wallet) else { return }
        if let idx = wallets.firstIndex(where: { $0.id == wallet.id }) {
            wallets[idx].balance = balance
        }
    }

    // MARK: - Private Key Access (requires biometric)

    func exportPrivateKey(wallet: Wallet, password: String) async throws -> String {
        let bio = BiometricAuthService()
        let result = await bio.authenticate(reason: "Authenticate to export private key")
        guard result.success else { throw WalletError.biometricFailed }

        let encrypted = try keychain.loadEncryptedPrivateKey(walletId: wallet.id.uuidString)
        return try encryption.decryptPrivateKey(encrypted, password: password)
    }

    func exportMnemonic(hdWalletId: String, password: String) async throws -> String {
        let bio = BiometricAuthService()
        let result = await bio.authenticate(reason: "Authenticate to view recovery phrase")
        guard result.success else { throw WalletError.biometricFailed }

        let encrypted = try keychain.loadMnemonic(hdWalletId: hdWalletId)
        return try encryption.decryptMnemonic(encrypted, password: password)
    }

    // MARK: - Persistence

    private func persistWallets() {
        let metadata = wallets.map { WalletMetadata(from: $0) }
        if let data = try? JSONEncoder().encode(metadata) {
            UserDefaults.standard.set(data, forKey: "wallets")
        }
    }

    func loadWallets() {
        guard let data = UserDefaults.standard.data(forKey: "wallets"),
              let metadata = try? JSONDecoder().decode([WalletMetadata].self, from: data)
        else { return }
        wallets = metadata.map { $0.toWallet() }
    }
}

// MARK: - Supporting Types

enum MnemonicWordCount: Int {
    case twelve = 12
    case twentyFour = 24
}

enum WalletError: LocalizedError {
    case invalidMnemonic
    case derivationFailed
    case keyNotFound
    case biometricFailed
    case invalidMultiSigConfig
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .invalidMnemonic: return "Invalid recovery phrase"
        case .derivationFailed: return "Failed to derive wallet address"
        case .keyNotFound: return "Private key not found in secure storage"
        case .biometricFailed: return "Biometric authentication failed"
        case .invalidMultiSigConfig: return "Required signatures cannot exceed total signers"
        case .networkError(let msg): return "Network error: \(msg)"
        }
    }
}

struct WalletMetadata: Codable {
    var id: String
    var name: String
    var chain: Chain
    var walletType: WalletType
    var address: String
    var derivationPath: String?
    var isPrimary: Bool
    var isArchived: Bool
    var bitcoinScriptType: BitcoinScriptType?
    var xpub: String?
    var multiSigConfig: MultiSigConfig?
    var hardwareWalletId: String?
    var createdAt: Date

    init(from wallet: Wallet) {
        id = wallet.id.uuidString
        name = wallet.name
        chain = wallet.chain
        walletType = wallet.walletType
        address = wallet.address
        derivationPath = wallet.derivationPath
        isPrimary = wallet.isPrimary
        isArchived = wallet.isArchived
        bitcoinScriptType = wallet.bitcoinScriptType
        xpub = wallet.xpub
        multiSigConfig = wallet.multiSigConfig
        hardwareWalletId = wallet.hardwareWalletId
        createdAt = wallet.createdAt
    }

    func toWallet() -> Wallet {
        var w = Wallet(
            id: UUID(uuidString: id) ?? UUID(),
            name: name,
            chain: chain,
            walletType: walletType,
            address: address,
            derivationPath: derivationPath,
            isPrimary: isPrimary,
            bitcoinScriptType: bitcoinScriptType
        )
        w.isArchived = isArchived
        w.xpub = xpub
        w.multiSigConfig = multiSigConfig
        w.hardwareWalletId = hardwareWalletId
        return w
    }
}
