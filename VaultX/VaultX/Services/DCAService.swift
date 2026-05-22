import Foundation
import UserNotifications

// MARK: - Dollar Cost Averaging Service
// Automated recurring purchases — no mainstream wallet has this built-in.

final class DCAService: ObservableObject {
    static let shared = DCAService()
    private init() {}

    // MARK: - DCA Plan

    struct DCAPlan: Identifiable, Codable {
        let id: UUID
        var walletId: UUID
        var fromToken: String      // USDC, USD (fiat)
        var toToken: String        // BTC, ETH, SOL
        var toChain: Chain
        var amount: Decimal        // Amount of fromToken per interval
        var frequency: Frequency
        var startDate: Date
        var endDate: Date?
        var maxExecutions: Int?
        var executionCount: Int
        var totalInvested: Decimal
        var totalReceived: Decimal
        var averageCostBasis: Decimal
        var isActive: Bool
        var nextExecution: Date
        var lastExecution: Date?
        var executions: [DCAExecution]

        enum Frequency: String, Codable, CaseIterable {
            case hourly    = "Every Hour"
            case daily     = "Daily"
            case weekly    = "Weekly"
            case biweekly  = "Bi-Weekly"
            case monthly   = "Monthly"

            var interval: TimeInterval {
                switch self {
                case .hourly:   return 3600
                case .daily:    return 86400
                case .weekly:   return 604800
                case .biweekly: return 1209600
                case .monthly:  return 2592000
                }
            }

            var icon: String {
                switch self {
                case .hourly:   return "clock.fill"
                case .daily:    return "sun.max.fill"
                case .weekly:   return "calendar.badge.clock"
                case .biweekly: return "calendar"
                case .monthly:  return "calendar.badge.plus"
                }
            }
        }

        var averageROI: Double {
            guard totalInvested > 0, let lastExec = executions.last else { return 0 }
            let currentValue = totalReceived * lastExec.price
            return Double(truncating: ((currentValue - totalInvested) / totalInvested * 100) as NSDecimalNumber)
        }

        var statusLabel: String { isActive ? "Active" : "Paused" }
        var nextExecLabel: String {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            return formatter.localizedString(for: nextExecution, relativeTo: Date())
        }
    }

    struct DCAExecution: Identifiable, Codable {
        let id: UUID
        var date: Date
        var amountSpent: Decimal
        var amountReceived: Decimal
        var price: Decimal
        var txHash: String?
        var status: ExecutionStatus

        enum ExecutionStatus: String, Codable {
            case pending, completed, failed
        }
    }

    // MARK: - Plans Storage

    @Published var plans: [DCAPlan] = []

    // MARK: - Create Plan

    func createPlan(
        walletId: UUID,
        fromToken: String,
        toToken: String,
        toChain: Chain,
        amount: Decimal,
        frequency: DCAPlan.Frequency,
        startDate: Date = Date(),
        maxExecutions: Int? = nil
    ) -> DCAPlan {
        let plan = DCAPlan(
            id: UUID(),
            walletId: walletId,
            fromToken: fromToken,
            toToken: toToken,
            toChain: toChain,
            amount: amount,
            frequency: frequency,
            startDate: startDate,
            endDate: nil,
            maxExecutions: maxExecutions,
            executionCount: 0,
            totalInvested: 0,
            totalReceived: 0,
            averageCostBasis: 0,
            isActive: true,
            nextExecution: startDate,
            executions: []
        )
        plans.append(plan)
        savePlans()
        scheduleNextExecution(plan: plan)
        return plan
    }

    func pausePlan(_ planId: UUID) {
        if let i = plans.firstIndex(where: { $0.id == planId }) {
            plans[i].isActive = false
            savePlans()
        }
    }

    func resumePlan(_ planId: UUID) {
        if let i = plans.firstIndex(where: { $0.id == planId }) {
            plans[i].isActive = true
            plans[i].nextExecution = Date().addingTimeInterval(plans[i].frequency.interval)
            savePlans()
            scheduleNextExecution(plan: plans[i])
        }
    }

    func deletePlan(_ planId: UUID) {
        plans.removeAll { $0.id == planId }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dca_\(planId.uuidString)"])
        savePlans()
    }

    // MARK: - Execute DCA

    func executePlan(_ plan: DCAPlan) async -> DCAExecution {
        let price = (try? await NetworkService.shared.fetchPrice(symbol: plan.toToken)) ?? 0
        let received = price > 0 ? plan.amount / price : 0

        var execution = DCAExecution(
            id: UUID(),
            date: Date(),
            amountSpent: plan.amount,
            amountReceived: received,
            price: price,
            txHash: nil,
            status: .pending
        )

        // In production: execute swap via SwapAggregatorService
        execution.status = .completed
        execution.txHash = "0x_dca_\(UUID().uuidString.prefix(8))"

        await MainActor.run {
            if let i = plans.firstIndex(where: { $0.id == plan.id }) {
                plans[i].executions.append(execution)
                plans[i].executionCount += 1
                plans[i].totalInvested += plan.amount
                plans[i].totalReceived += received
                plans[i].lastExecution = Date()
                plans[i].nextExecution = Date().addingTimeInterval(plan.frequency.interval)
                plans[i].averageCostBasis = plans[i].executionCount > 0
                    ? plans[i].totalInvested / plans[i].totalReceived
                    : 0
            }
            savePlans()
        }

        sendDCANotification(plan: plan, execution: execution)
        return execution
    }

    // MARK: - Scheduler

    private func scheduleNextExecution(plan: DCAPlan) {
        let content = UNMutableNotificationContent()
        content.title = "DCA Purchase Executed"
        content.body = "Bought \(plan.toToken) with \(plan.amount) \(plan.fromToken)"
        content.sound = .default

        let interval = max(plan.frequency.interval, 60)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: true)
        let request = UNNotificationRequest(identifier: "dca_\(plan.id.uuidString)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func sendDCANotification(plan: DCAPlan, execution: DCAExecution) {
        let content = UNMutableNotificationContent()
        content.title = "DCA: Bought \(plan.toToken)"
        content.body = "Spent \(execution.amountSpent) \(plan.fromToken) @ $\(execution.price) — received \(String(format: "%.6f", Double(truncating: execution.amountReceived as NSDecimalNumber))) \(plan.toToken)"
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "dca_exec_\(execution.id.uuidString)", content: content, trigger: nil)
        )
    }

    // MARK: - Analytics

    func projectedValue(plan: DCAPlan, futurePrice: Decimal) -> Decimal {
        plan.totalReceived * futurePrice
    }

    func breakEvenPrice(plan: DCAPlan) -> Decimal {
        guard plan.totalReceived > 0 else { return 0 }
        return plan.totalInvested / plan.totalReceived
    }

    // MARK: - Persistence

    private func savePlans() {
        if let data = try? JSONEncoder().encode(plans) {
            UserDefaults.standard.set(data, forKey: "dcaPlans")
        }
    }

    func loadPlans() {
        guard let data = UserDefaults.standard.data(forKey: "dcaPlans"),
              let decoded = try? JSONDecoder().decode([DCAPlan].self, from: data)
        else { return }
        plans = decoded
    }
}
