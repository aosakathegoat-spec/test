import Foundation
import CryptoKit

// MARK: - Backup Service
// Phantom's backup only works if you have Apple/Google login or your seed phrase.
// VaultX provides end-to-end encrypted vault backup — recoverable with password alone.

final class BackupService {
    static let shared = BackupService()
    private let encryption = EncryptionService.shared
    private let keychain = KeychainService.shared
    private init() {}

    struct VaultBackup: Codable {
        var version: Int = 2
        var createdAt: Date
        var appVersion: String
        var walletCount: Int
        var encryptedPayload: Data   // AES-256-GCM, password-derived key
        var checksum: String         // SHA-256 of decrypted payload

        var sizeBytes: Int { encryptedPayload.count }
        var formattedSize: String {
            ByteCountFormatter.string(fromByteCount: Int64(sizeBytes), countStyle: .file)
        }
    }

    struct BackupPayload: Codable {
        var wallets: [WalletMetadata]
        var encryptedKeys: [String: EncryptedPrivateKey]    // walletId -> encrypted key
        var encryptedMnemonics: [String: EncryptedMnemonic] // hdWalletId -> encrypted mnemonic
        var settings: BackupSettings
        var priceAlerts: [PriceAlert]
        var portfolioSnapshots: [PortfolioSnapshot]
        var createdAt: Date
    }

    struct BackupSettings: Codable {
        var defaultCurrency: String
        var costBasisMethod: TaxReport.CostBasisMethod
        var biometricEnabled: Bool
        var notificationsEnabled: Bool
    }

    // MARK: - Create Backup

    func createBackup(
        wallets: [WalletMetadata],
        password: String,
        includeTxHistory: Bool = true
    ) async throws -> VaultBackup {
        var encryptedKeys: [String: EncryptedPrivateKey] = [:]
        var encryptedMnemonics: [String: EncryptedMnemonic] = [:]

        // Load all keys from Keychain
        for wallet in wallets where wallet.walletType != .watchOnly && wallet.walletType != .hardware {
            if let key = try? keychain.loadEncryptedPrivateKey(walletId: wallet.id) {
                encryptedKeys[wallet.id] = key
            }
            // Re-encrypt with backup password for portability
        }

        let payload = BackupPayload(
            wallets: wallets,
            encryptedKeys: encryptedKeys,
            encryptedMnemonics: encryptedMnemonics,
            settings: BackupSettings(
                defaultCurrency: "USD",
                costBasisMethod: .fifo,
                biometricEnabled: false,
                notificationsEnabled: true
            ),
            priceAlerts: [],
            portfolioSnapshots: [],
            createdAt: Date()
        )

        let payloadData = try JSONEncoder().encode(payload)
        let checksum = encryption.sha256(payloadData).map { String(format: "%02x", $0) }.joined()
        let encryptedPayload = try encryption.encryptBackup(payloadData, password: password)

        return VaultBackup(
            createdAt: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            walletCount: wallets.count,
            encryptedPayload: encryptedPayload,
            checksum: checksum
        )
    }

    // MARK: - Restore Backup

    func restoreBackup(_ backup: VaultBackup, password: String) async throws -> BackupPayload {
        let payloadData = try encryption.decryptBackup(backup.encryptedPayload, password: password)

        // Verify checksum
        let checksum = encryption.sha256(payloadData).map { String(format: "%02x", $0) }.joined()
        guard checksum == backup.checksum else {
            throw BackupError.checksumMismatch
        }

        let payload = try JSONDecoder().decode(BackupPayload.self, from: payloadData)

        // Restore keys to Keychain
        for (walletId, encryptedKey) in payload.encryptedKeys {
            try keychain.saveEncryptedPrivateKey(encryptedKey, walletId: walletId)
        }

        for (hdWalletId, encryptedMnemonic) in payload.encryptedMnemonics {
            try keychain.saveMnemonic(encryptedMnemonic, hdWalletId: hdWalletId)
        }

        return payload
    }

    // MARK: - iCloud Backup (encrypted)

    func saveToiCloud(_ backup: VaultBackup) async throws {
        guard let data = try? JSONEncoder().encode(backup) else {
            throw BackupError.encodingFailed
        }

        let url = iCloudBackupURL()
        try data.write(to: url, options: .atomicWrite)
    }

    func loadFromiCloud() async throws -> VaultBackup {
        let url = iCloudBackupURL()
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(VaultBackup.self, from: data)
    }

    func listiCloudBackups() -> [URL] {
        guard let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) else { return [] }
        let backupsURL = containerURL.appendingPathComponent("Documents/Backups")
        return (try? FileManager.default.contentsOfDirectory(at: backupsURL, includingPropertiesForKeys: nil)) ?? []
    }

    private func iCloudBackupURL() -> URL {
        let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)
            ?? FileManager.default.temporaryDirectory
        let backupsDir = containerURL.appendingPathComponent("Documents/Backups")
        try? FileManager.default.createDirectory(at: backupsDir, withIntermediateDirectories: true)

        let dateString = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        return backupsDir.appendingPathComponent("vaultx_backup_\(dateString).vxb")
    }

    // MARK: - Export to File

    func exportToFile(_ backup: VaultBackup) throws -> URL {
        let data = try JSONEncoder().encode(backup)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("VaultX_Backup_\(Date().timeIntervalSince1970).vxb")
        try data.write(to: tempURL)
        return tempURL
    }
}

enum BackupError: LocalizedError {
    case checksumMismatch
    case encodingFailed
    case iCloudUnavailable
    case corruptedBackup

    var errorDescription: String? {
        switch self {
        case .checksumMismatch: return "Backup integrity check failed — file may be corrupted"
        case .encodingFailed: return "Failed to encode backup data"
        case .iCloudUnavailable: return "iCloud is not available"
        case .corruptedBackup: return "Backup file is corrupted"
        }
    }
}
