import Foundation
import CryptoKit

// MARK: - 2FA Service
// Phantom Wallet has NO 2FA at all. This is one of our biggest security differentiators.

final class TwoFactorAuthService {
    static let shared = TwoFactorAuthService()
    private init() {}

    private let issuer = "VaultX Wallet"
    private let digits = 6
    private let period: TimeInterval = 30
    private let algorithm = "SHA1"

    // MARK: - Setup

    /// Generates a new TOTP secret and returns the provisioning URI for QR code display
    func generateSecret() -> (secret: String, provisioningURI: String) {
        let secret = generateBase32Secret()
        return (secret, makeProvisioningURI(secret: secret, accountName: ""))
    }

    func makeProvisioningURI(secret: String, accountName: String) -> String {
        let encoded = accountName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? accountName
        return "otpauth://totp/\(issuer):\(encoded)?secret=\(secret)&issuer=\(issuer)&algorithm=\(algorithm)&digits=\(digits)&period=\(Int(period))"
    }

    // MARK: - TOTP Generation

    func generateTOTP(secret: String, at date: Date = Date()) -> String? {
        guard let secretData = base32Decode(secret) else { return nil }

        let counter = UInt64(date.timeIntervalSince1970 / period)
        return hotp(key: secretData, counter: counter)
    }

    // MARK: - TOTP Verification (with drift window ±1 step)

    func verify(code: String, secret: String, at date: Date = Date(), window: Int = 1) -> Bool {
        guard code.count == digits, code.allSatisfy({ $0.isNumber }) else { return false }
        guard let secretData = base32Decode(secret) else { return false }

        let currentStep = UInt64(date.timeIntervalSince1970 / period)

        for offset in -window...window {
            let step = UInt64(Int64(currentStep) + Int64(offset))
            if let token = hotp(key: secretData, counter: step), token == code {
                return true
            }
        }
        return false
    }

    // MARK: - Backup Codes

    /// Generates 10 one-time backup codes — for account recovery when device is lost
    func generateBackupCodes() -> [String] {
        (0..<10).map { _ in
            let bytes = (0..<4).map { _ -> UInt8 in
                var byte: UInt8 = 0
                _ = SecRandomCopyBytes(kSecRandomDefault, 1, &byte)
                return byte
            }
            let value = UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3])
            return String(format: "%04d-%04d", value >> 16, value & 0xFFFF)
        }
    }

    func hashBackupCode(_ code: String) -> String {
        EncryptionService.shared.sha256(code.replacingOccurrences(of: "-", with: ""))
    }

    // MARK: - HOTP

    private func hotp(key: Data, counter: UInt64) -> String? {
        var counterBigEndian = counter.bigEndian
        let counterData = Data(bytes: &counterBigEndian, count: 8)

        let symmetricKey = SymmetricKey(data: key)
        let mac = HMAC<Insecure.SHA1>.authenticationCode(for: counterData, using: symmetricKey)
        let hmacBytes = Array(mac)

        let offset = Int(hmacBytes[hmacBytes.count - 1] & 0x0f)
        let truncated = (Int(hmacBytes[offset] & 0x7f) << 24)
            | (Int(hmacBytes[offset + 1]) << 16)
            | (Int(hmacBytes[offset + 2]) << 8)
            | Int(hmacBytes[offset + 3])

        let otp = truncated % Int(pow(10.0, Double(digits)))
        return String(format: "%0\(digits)d", otp)
    }

    // MARK: - Base32

    private let base32Alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"

    func generateBase32Secret(length: Int = 20) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)

        var result = ""
        var buffer = 0
        var bitsLeft = 0

        for byte in bytes {
            buffer = (buffer << 8) | Int(byte)
            bitsLeft += 8
            while bitsLeft >= 5 {
                bitsLeft -= 5
                let index = (buffer >> bitsLeft) & 0x1f
                result.append(base32Alphabet[base32Alphabet.index(base32Alphabet.startIndex, offsetBy: index)])
            }
        }

        return result
    }

    func base32Decode(_ encoded: String) -> Data? {
        var result = [UInt8]()
        var buffer = 0
        var bitsLeft = 0

        for char in encoded.uppercased() {
            guard char != "=" else { break }
            guard let index = base32Alphabet.firstIndex(of: char) else { return nil }
            let value = base32Alphabet.distance(from: base32Alphabet.startIndex, to: index)
            buffer = (buffer << 5) | value
            bitsLeft += 5
            if bitsLeft >= 8 {
                bitsLeft -= 8
                result.append(UInt8(truncatingIfNeeded: buffer >> bitsLeft))
            }
        }

        return Data(result)
    }
}
