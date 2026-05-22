import Foundation
import UserNotifications

// MARK: - Notification Service
// Phantom has no price alerts or wallet monitoring notifications.

final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    // MARK: - Price Alerts

    func sendPriceAlert(alert: PriceAlert) {
        guard let currentPrice = alert.currentPrice else { return }

        let content = UNMutableNotificationContent()
        content.title = "Price Alert: \(alert.symbol)"
        content.body = alertBody(alert: alert, currentPrice: currentPrice)
        content.sound = .default
        content.categoryIdentifier = "PRICE_ALERT"
        content.userInfo = ["alertId": alert.id.uuidString, "symbol": alert.symbol]

        let request = UNNotificationRequest(
            identifier: "price_alert_\(alert.id.uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func alertBody(alert: PriceAlert, currentPrice: Decimal) -> String {
        switch alert.alertType {
        case .priceAbove:
            return "\(alert.symbol) reached $\(currentPrice) (target: $\(alert.targetPrice))"
        case .priceBelow:
            return "\(alert.symbol) dropped to $\(currentPrice) (target: $\(alert.targetPrice))"
        default:
            return "\(alert.symbol) price alert triggered at $\(currentPrice)"
        }
    }

    // MARK: - Security Alerts

    func sendSecurityAlert(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = "Security Alert — \(title)"
        content.body = body
        content.sound = UNNotificationSound(named: UNNotificationSoundName("security_alert.aiff"))
        content.categoryIdentifier = "SECURITY_ALERT"
        content.interruptionLevel = .critical

        let request = UNNotificationRequest(
            identifier: "security_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Transaction Notifications

    func sendTransactionConfirmed(txHash: String, amount: Decimal, symbol: String) {
        let content = UNMutableNotificationContent()
        content.title = "Transaction Confirmed"
        content.body = "\(amount) \(symbol) has been sent successfully"
        content.sound = .default
        content.userInfo = ["txHash": txHash]

        UNUserNotificationCenter.current().add(
            UNNotificationRequest(
                identifier: "tx_\(txHash.prefix(10))",
                content: content,
                trigger: nil
            )
        )
    }

    func sendIncomingTransaction(amount: Decimal, symbol: String, from: String) {
        let content = UNMutableNotificationContent()
        content.title = "Incoming Transaction"
        content.body = "Received \(amount) \(symbol) from \(from.prefix(6))...\(from.suffix(4))"
        content.sound = .default

        UNUserNotificationCenter.current().add(
            UNNotificationRequest(
                identifier: "incoming_\(UUID().uuidString)",
                content: content,
                trigger: nil
            )
        )
    }

    // MARK: - Multi-Sig Notifications

    func sendMultiSigRequest(wallet: Wallet, pendingTx: PendingMultiSigTx) {
        let content = UNMutableNotificationContent()
        content.title = "Signature Required"
        content.body = "Multi-sig wallet '\(wallet.name)' needs your signature to send \(pendingTx.amount) \(pendingTx.symbol)"
        content.sound = .default
        content.categoryIdentifier = "MULTISIG_REQUEST"
        content.userInfo = ["pendingTxId": pendingTx.id.uuidString]

        UNUserNotificationCenter.current().add(
            UNNotificationRequest(
                identifier: "multisig_\(pendingTx.id.uuidString)",
                content: content,
                trigger: nil
            )
        )
    }

    // MARK: - Register Notification Categories

    func registerCategories() {
        let viewAction = UNNotificationAction(identifier: "VIEW", title: "View", options: .foreground)
        let dismissAction = UNNotificationAction(identifier: "DISMISS", title: "Dismiss", options: .destructive)

        let priceAlertCategory = UNNotificationCategory(
            identifier: "PRICE_ALERT",
            actions: [viewAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )

        let securityCategory = UNNotificationCategory(
            identifier: "SECURITY_ALERT",
            actions: [viewAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        let multiSigCategory = UNNotificationCategory(
            identifier: "MULTISIG_REQUEST",
            actions: [
                UNNotificationAction(identifier: "SIGN", title: "Sign Now", options: .foreground),
                dismissAction,
            ],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            priceAlertCategory, securityCategory, multiSigCategory,
        ])
    }
}
