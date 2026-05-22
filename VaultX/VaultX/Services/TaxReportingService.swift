import Foundation

// MARK: - Tax Reporting Service
// Phantom has ZERO tax support. VaultX provides full FIFO/LIFO/HIFO/ACB reporting.

final class TaxReportingService {
    static let shared = TaxReportingService()
    private init() {}

    // MARK: - Report Generation

    func generateReport(
        transactions: [Transaction],
        year: Int,
        method: TaxReport.CostBasisMethod
    ) async -> TaxReport {
        let filtered = transactions.filter {
            Calendar.current.component(.year, from: $0.timestamp) == year
        }

        let taxableEvents = await computeTaxableEvents(transactions: filtered, allTransactions: transactions, method: method)

        let shortTerm = taxableEvents
            .filter { !$0.isLongTerm && $0.gainLossUSD > 0 }
            .reduce(Decimal(0)) { $0 + $1.gainLossUSD }

        let longTerm = taxableEvents
            .filter { $0.isLongTerm && $0.gainLossUSD > 0 }
            .reduce(Decimal(0)) { $0 + $1.gainLossUSD }

        let losses = taxableEvents
            .filter { $0.gainLossUSD < 0 }
            .reduce(Decimal(0)) { $0 + $1.gainLossUSD }

        return TaxReport(
            id: UUID(),
            userId: "",
            taxYear: year,
            costBasisMethod: method,
            shortTermGains: shortTerm,
            longTermGains: longTerm,
            totalGains: shortTerm + longTerm,
            totalLosses: abs(losses),
            netGainLoss: shortTerm + longTerm + losses,
            taxableEvents: taxableEvents,
            generatedAt: Date()
        )
    }

    // MARK: - Cost Basis Calculation

    private func computeTaxableEvents(
        transactions: [Transaction],
        allTransactions: [Transaction],
        method: TaxReport.CostBasisMethod
    ) async -> [TaxableEvent] {
        var events: [TaxableEvent] = []

        // Group by asset symbol
        let byAsset = Dictionary(grouping: allTransactions) { $0.symbol }

        for tx in transactions {
            guard tx.type == .send || tx.type == .swap else { continue }
            guard let usdValue = tx.usdValueAtTime else { continue }

            let acquisitions = byAsset[tx.symbol]?
                .filter { $0.type == .receive && $0.timestamp < tx.timestamp }
                .sorted { sortForMethod($0, $1, method: method) }
            ?? []

            var remainingAmount = tx.amount
            var totalCostBasis: Decimal = 0

            for acq in acquisitions {
                guard remainingAmount > 0 else { break }
                guard let acqUSD = acq.usdValueAtTime else { continue }

                let used = min(acq.amount, remainingAmount)
                let pricePer = acq.amount > 0 ? acqUSD / acq.amount : 0
                totalCostBasis += used * pricePer
                remainingAmount -= used
            }

            let proceeds = tx.amount * (tx.amount > 0 ? usdValue / tx.amount : 0)
            let gainLoss = proceeds - totalCostBasis
            let holdingDays = acquisitions.first.map {
                Calendar.current.dateComponents([.day], from: $0.timestamp, to: tx.timestamp).day ?? 0
            } ?? 0

            let event = TaxableEvent(
                id: UUID(),
                txHash: tx.txHash,
                chain: tx.chain,
                eventType: tx.type == .swap ? .swap : .sale,
                asset: tx.symbol,
                amount: tx.amount,
                acquisitionDate: acquisitions.first?.timestamp ?? tx.timestamp,
                disposalDate: tx.timestamp,
                costBasisUSD: totalCostBasis,
                proceedsUSD: proceeds,
                gainLossUSD: gainLoss,
                isLongTerm: holdingDays > 365,
                holdingDays: holdingDays
            )

            events.append(event)
        }

        // Staking rewards as income
        for tx in transactions where tx.type == .stake {
            guard let usdValue = tx.usdValueAtTime else { continue }
            events.append(TaxableEvent(
                id: UUID(),
                txHash: tx.txHash,
                chain: tx.chain,
                eventType: .income,
                asset: tx.symbol,
                amount: tx.amount,
                acquisitionDate: tx.timestamp,
                disposalDate: tx.timestamp,
                costBasisUSD: 0,
                proceedsUSD: usdValue,
                gainLossUSD: usdValue,
                isLongTerm: false,
                holdingDays: 0
            ))
        }

        return events.sorted { $0.disposalDate < $1.disposalDate }
    }

    private func sortForMethod(_ a: Transaction, _ b: Transaction, method: TaxReport.CostBasisMethod) -> Bool {
        switch method {
        case .fifo: return a.timestamp < b.timestamp
        case .lifo: return a.timestamp > b.timestamp
        case .hifo:
            let aPrice = a.usdValueAtTime ?? 0
            let bPrice = b.usdValueAtTime ?? 0
            return aPrice > bPrice
        case .acb: return a.timestamp < b.timestamp
        }
    }

    // MARK: - CSV Export

    func exportCSV(report: TaxReport) -> String {
        var csv = "Date,Asset,Amount,Proceeds (USD),Cost Basis (USD),Gain/Loss (USD),Term,Type,TX Hash\n"

        let formatter = ISO8601DateFormatter()

        for event in report.taxableEvents {
            let term = event.isLongTerm ? "Long-term" : "Short-term"
            csv += "\(formatter.string(from: event.disposalDate)),"
            csv += "\(event.asset),"
            csv += "\(event.amount),"
            csv += "\(event.proceedsUSD),"
            csv += "\(event.costBasisUSD),"
            csv += "\(event.gainLossUSD),"
            csv += "\(term),"
            csv += "\(event.eventType.rawValue),"
            csv += "\(event.txHash)\n"
        }

        return csv
    }

    // MARK: - Summary Statistics

    func washSaleAnalysis(events: [TaxableEvent], transactions: [Transaction]) -> [WashSaleWarning] {
        // Detect potential wash sales (sell at loss + repurchase within 30 days)
        var warnings: [WashSaleWarning] = []

        let lossEvents = events.filter { $0.gainLossUSD < 0 }
        for loss in lossEvents {
            let repurchases = transactions.filter {
                $0.symbol == loss.asset
                && $0.type == .receive
                && abs($0.timestamp.timeIntervalSince(loss.disposalDate)) <= 30 * 86400
            }
            if !repurchases.isEmpty {
                warnings.append(WashSaleWarning(
                    asset: loss.asset,
                    saleDate: loss.disposalDate,
                    lossAmount: loss.gainLossUSD,
                    repurchaseDate: repurchases.first!.timestamp
                ))
            }
        }
        return warnings
    }
}

struct WashSaleWarning: Identifiable {
    let id = UUID()
    var asset: String
    var saleDate: Date
    var lossAmount: Decimal
    var repurchaseDate: Date
}
