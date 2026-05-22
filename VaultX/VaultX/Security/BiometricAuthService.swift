import LocalAuthentication
import Foundation

struct BiometricResult {
    let success: Bool
    let error: BiometricError?
}

enum BiometricError: LocalizedError {
    case notAvailable
    case notEnrolled
    case lockout
    case cancelled
    case failed
    case passcodeNotSet

    var errorDescription: String? {
        switch self {
        case .notAvailable: return "Biometric authentication is not available on this device"
        case .notEnrolled: return "No biometrics enrolled. Please set up Face ID or Touch ID in Settings"
        case .lockout: return "Too many failed attempts. Use your passcode to unlock"
        case .cancelled: return "Authentication was cancelled"
        case .failed: return "Biometric authentication failed"
        case .passcodeNotSet: return "A passcode must be set to use biometrics"
        }
    }
}

final class BiometricAuthService {
    var availableBiometryType: LABiometryType {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        return context.biometryType
    }

    var isFaceIDAvailable: Bool { availableBiometryType == .faceID }
    var isTouchIDAvailable: Bool { availableBiometryType == .touchID }
    var isAvailable: Bool { availableBiometryType != .none }

    var biometryName: String {
        switch availableBiometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "Biometrics"
        }
    }

    func authenticate(reason: String) async -> BiometricResult {
        let context = LAContext()
        context.localizedCancelTitle = "Use Passcode"

        var authError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) else {
            return BiometricResult(success: false, error: mapLAError(authError))
        }

        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            ) { success, error in
                if success {
                    continuation.resume(returning: BiometricResult(success: true, error: nil))
                } else {
                    continuation.resume(returning: BiometricResult(
                        success: false,
                        error: self.mapLAError(error as NSError?)
                    ))
                }
            }
        }
    }

    /// Full device auth — falls back to passcode if biometrics fails
    func authenticateWithFallback(reason: String) async -> BiometricResult {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        var authError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) else {
            return BiometricResult(success: false, error: mapLAError(authError))
        }

        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            ) { success, error in
                continuation.resume(returning: BiometricResult(
                    success: success,
                    error: success ? nil : self.mapLAError(error as NSError?)
                ))
            }
        }
    }

    private func mapLAError(_ error: NSError?) -> BiometricError {
        guard let error else { return .failed }
        switch error.code {
        case LAError.biometryNotAvailable.rawValue: return .notAvailable
        case LAError.biometryNotEnrolled.rawValue: return .notEnrolled
        case LAError.biometryLockout.rawValue: return .lockout
        case LAError.userCancel.rawValue, LAError.appCancel.rawValue: return .cancelled
        case LAError.passcodeNotSet.rawValue: return .passcodeNotSet
        default: return .failed
        }
    }
}
