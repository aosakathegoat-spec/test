import StoreKit
import Foundation

@MainActor
class PurchaseService: ObservableObject {
    static let shared = PurchaseService()

    @Published var products: [Product] = []
    @Published var purchaseError: String?
    @Published var isLoading = false

    private var updateListenerTask: Task<Void, Error>?

    private init() {
        updateListenerTask = listenForTransactionUpdates()
        Task { await loadProducts() }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let ids: [String] = [
                Constants.Products.coreMonthly,
                Constants.Products.proMonthly,
                Constants.Products.ultraMonthly
            ]
            products = try await Product.products(for: Set(ids))
                .sorted { ($0.price) < ($1.price) }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    func purchase(_ plan: SubscriptionPlan) async throws -> Bool {
        guard let productID = plan.productID else { return true }
        guard let product = products.first(where: { $0.id == productID }) else {
            throw PurchaseError.productNotFound
        }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            TokenTracker.shared.updatePlan(plan)
            await transaction.finish()
            return true
        case .userCancelled:
            return false
        case .pending:
            return false
        @unknown default:
            return false
        }
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
        await updateCurrentPlan()
    }

    func updateCurrentPlan() async {
        var activePlan = SubscriptionPlan.free
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.revocationDate == nil else { continue }

            if transaction.productID == Constants.Products.ultraMonthly { activePlan = .ultra; break }
            if transaction.productID == Constants.Products.proMonthly   { activePlan = .pro }
            else if transaction.productID == Constants.Products.coreMonthly && activePlan == .free {
                activePlan = .core
            }
        }
        TokenTracker.shared.updatePlan(activePlan)
    }

    func product(for plan: SubscriptionPlan) -> Product? {
        guard let id = plan.productID else { return nil }
        return products.first { $0.id == id }
    }

    func priceString(for plan: SubscriptionPlan) -> String {
        if let product = product(for: plan) {
            return product.displayPrice + "/mo"
        }
        return plan.priceDisplay
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw PurchaseError.failedVerification
        case .verified(let value): return value
        }
    }

    private func listenForTransactionUpdates() -> Task<Void, Error> {
        Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard let self else { break }
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self.updateCurrentPlan()
                }
            }
        }
    }
}

enum PurchaseError: LocalizedError {
    case productNotFound
    case failedVerification

    var errorDescription: String? {
        switch self {
        case .productNotFound:    return "Product not available. Please try again later."
        case .failedVerification: return "Purchase verification failed."
        }
    }
}
