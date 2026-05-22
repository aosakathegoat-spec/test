import Foundation
import Combine
import CryptoKit

@MainActor
final class SecurityManager: ObservableObject {
    @Published var securityScore: Int = 0
    @Published var securityIssues: [SecurityIssue] = []
    @Published var recentEvents: [SecurityEvent] = []

    private let keychain = KeychainService.shared
    private let encryption = EncryptionService.shared
    private let biometric = BiometricAuthService()
    private let phishing = PhishingDetectionService.shared
    private var cancellables = Set<AnyCancellable>()

    struct SecurityIssue: Identifiable {
        let id = UUID()
        var severity: Severity
        var title: String
        var description: String
        var actionLabel: String
        var action: () -> Void

        enum Severity: Int, Comparable {
            case info = 0, warning = 1, critical = 2
            static func < (lhs: Severity, rhs: Severity) -> Bool { lhs.rawValue < rhs.rawValue }
        }
    }

    struct SecurityEvent: Identifiable, Codable {
        let id: UUID
        var type: EventType
        var description: String
        var ipAddress: String?
        var deviceName: String?
        var timestamp: Date
        var severity: String

        enum EventType: String, Codable {
            case login, logout, loginFailed, walletCreated, walletImported
            case transactionSent, twoFAEnabled, twoFADisabled
            case biometricEnabled, deviceTrusted, deviceRevoked
            case backupCreated, backupRestored
            case suspiciousTxBlocked, phishingSiteBlocked
        }
    }

    // MARK: - Security Score

    func calculateSecurityScore(user: User) {
        var score = 0
        var issues: [SecurityIssue] = []

        // 2FA check (40 points) — this is a top Phantom gap
        if user.twoFactorEnabled {
            score += 40
        } else {
            issues.append(SecurityIssue(
                severity: .critical,
                title: "Two-Factor Authentication Disabled",
                description: "Enable 2FA to protect your account from unauthorized access. Phantom doesn't offer this at all.",
                actionLabel: "Enable 2FA",
                action: {}
            ))
        }

        // Biometric check (20 points)
        if biometric.isAvailable && user.biometricEnabled {
            score += 20
        } else if biometric.isAvailable {
            issues.append(SecurityIssue(
                severity: .warning,
                title: "\(biometric.biometryName) Not Enabled",
                description: "Enable \(biometric.biometryName) for faster and more secure app access",
                actionLabel: "Enable \(biometric.biometryName)",
                action: {}
            ))
        }

        // Strong password (20 points — assessed during login)
        if user.hasStrongPassword {
            score += 20
        } else {
            issues.append(SecurityIssue(
                severity: .warning,
                title: "Weak Password",
                description: "Your password does not meet strong security requirements",
                actionLabel: "Change Password",
                action: {}
            ))
        }

        // Backup created (20 points)
        if user.hasEncryptedBackup {
            score += 20
        } else {
            issues.append(SecurityIssue(
                severity: .warning,
                title: "No Encrypted Backup",
                description: "Create an encrypted backup in case you lose your device",
                actionLabel: "Create Backup",
                action: {}
            ))
        }

        self.securityScore = score
        self.securityIssues = issues.sorted { $0.severity > $1.severity }
    }

    // MARK: - Memory Security

    /// Wipe any in-memory sensitive strings — called on app background
    func clearSensitiveMemory() {
        // In Swift, we can zero out Data buffers for private keys
        NotificationCenter.default.post(name: .clearSensitiveData, object: nil)
    }

    // MARK: - Transaction Security Check

    func checkTransaction(
        to: String,
        amount: Decimal,
        amountUSD: Decimal,
        chain: Chain,
        inputData: String?
    ) -> PhishingDetectionService.TransactionRiskResult {
        return phishing.scoreTransaction(
            toAddress: to,
            amount: amount,
            amountUSD: amountUSD,
            chain: chain,
            inputData: inputData
        )
    }

    // MARK: - Device Security

    func assessDeviceSecurity() -> DeviceSecurityStatus {
        var issues: [String] = []
        var isCompromised = false

        // Jailbreak detection
        if isJailbroken() {
            issues.append("Device appears to be jailbroken — private keys are at risk")
            isCompromised = true
        }

        // Debugger check
        if isDebuggerAttached() {
            issues.append("Debugger detected — potential security risk")
            isCompromised = true
        }

        return DeviceSecurityStatus(isCompromised: isCompromised, issues: issues)
    }

    struct DeviceSecurityStatus {
        var isCompromised: Bool
        var issues: [String]
    }

    private func isJailbroken() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        let jailbreakPaths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt/",
        ]
        return jailbreakPaths.contains { FileManager.default.fileExists(atPath: $0) }
        #endif
    }

    private func isDebuggerAttached() -> Bool {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        let result = sysctl(&mib, 4, &info, &size, nil, 0)
        guard result == 0 else { return false }
        return (info.kp_proc.p_flag & P_TRACED) != 0
    }
}

// MARK: - User Security Properties (extension placeholder)

extension User {
    var twoFactorEnabled: Bool { return false }   // From UserDefaults/backend
    var biometricEnabled: Bool { return false }
    var hasStrongPassword: Bool { return true }
    var hasEncryptedBackup: Bool { return false }
}

struct User {
    var id: String
    var email: String
    var displayName: String?
}

extension Notification.Name {
    static let clearSensitiveData = Notification.Name("clearSensitiveData")
}
