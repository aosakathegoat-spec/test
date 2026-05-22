import SwiftUI

// MARK: - Tax Report View
// Phantom has ZERO built-in tax support. VaultX provides full FIFO/LIFO/HIFO reporting.

struct TaxReportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedYear = Calendar.current.component(.year, from: Date()) - 1
    @State private var selectedMethod: TaxReport.CostBasisMethod = .fifo
    @State private var report: TaxReport?
    @State private var isGenerating = false
    @State private var showingExport = false

    private let taxService = TaxReportingService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        configSection
                        if let report {
                            summarySection(report: report)
                            eventsSection(report: report)
                            exportSection(report: report)
                        } else if isGenerating {
                            ProgressView("Calculating...")
                                .tint(.purple)
                                .foregroundColor(.gray)
                                .padding(40)
                        } else {
                            generatePrompt
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Tax Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var configSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Tax Year")
                    .foregroundColor(.gray)
                Spacer()
                Picker("Year", selection: $selectedYear) {
                    ForEach((2020...Calendar.current.component(.year, from: Date())).reversed(), id: \.self) { year in
                        Text(String(year)).tag(year)
                    }
                }
                .pickerStyle(.menu)
                .tint(.purple)
            }

            HStack {
                Text("Cost Basis Method")
                    .foregroundColor(.gray)
                Spacer()
                Picker("Method", selection: $selectedMethod) {
                    ForEach(TaxReport.CostBasisMethod.allCases, id: \.self) { method in
                        Text(method.rawValue).tag(method)
                    }
                }
                .pickerStyle(.menu)
                .tint(.purple)
            }

            // Method explanation
            VStack(alignment: .leading, spacing: 4) {
                Text(methodExplanation)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var methodExplanation: String {
        switch selectedMethod {
        case .fifo: return "FIFO: First purchased coins are sold first. Standard method in most countries."
        case .lifo: return "LIFO: Most recently purchased coins are sold first. May reduce taxable gains."
        case .hifo: return "HIFO: Highest cost basis sold first — minimizes short-term capital gains."
        case .acb: return "ACB: Adjusted Cost Base — used in Canada. Averages all purchase prices."
        }
    }

    private var generatePrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.purple.opacity(0.6))
            Text("Generate your \(selectedYear) tax report using the \(selectedMethod.rawValue) method")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)

            Button(action: generateReport) {
                Text("Generate Report")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(40)
    }

    private func summarySection(report: TaxReport) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("\(report.taxYear) Summary — \(report.costBasisMethod.rawValue)")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                TaxMetricCard(
                    title: "Short-term Gains",
                    amount: report.shortTermGains,
                    color: report.shortTermGains >= 0 ? .red : .green,
                    note: "< 1 year"
                )
                TaxMetricCard(
                    title: "Long-term Gains",
                    amount: report.longTermGains,
                    color: report.longTermGains >= 0 ? .orange : .green,
                    note: "> 1 year"
                )
                TaxMetricCard(
                    title: "Total Losses",
                    amount: -report.totalLosses,
                    color: .green,
                    note: "Tax deductible"
                )
                TaxMetricCard(
                    title: "Net Gain/Loss",
                    amount: report.netGainLoss,
                    color: report.netGainLoss >= 0 ? .red : .green,
                    note: "Total"
                )
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func eventsSection(report: TaxReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(report.taxableEvents.count) Taxable Events")
                .font(.headline)
                .foregroundColor(.white)

            ForEach(report.taxableEvents.prefix(20)) { event in
                TaxEventRow(event: event)
            }

            if report.taxableEvents.count > 20 {
                Text("+ \(report.taxableEvents.count - 20) more events in export")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func exportSection(report: TaxReport) -> some View {
        VStack(spacing: 12) {
            Button {
                let csv = taxService.exportCSV(report: report)
                shareCSV(csv, filename: "VaultX_Tax_\(report.taxYear)_\(report.costBasisMethod.rawValue).csv")
            } label: {
                Label("Export CSV", systemImage: "square.and.arrow.up.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color.green.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12).stroke(Color.green.opacity(0.3), lineWidth: 1)
                    )
            }

            Text("Compatible with TurboTax, TaxAct, Koinly, CoinTracker")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
    }

    private func generateReport() {
        isGenerating = true
        Task {
            // In production: pass actual transactions from WalletManager
            let result = await taxService.generateReport(transactions: [], year: selectedYear, method: selectedMethod)
            await MainActor.run {
                report = result
                isGenerating = false
            }
        }
    }

    private func shareCSV(_ content: String, filename: String) {
        guard let data = content.data(using: .utf8) else { return }
        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: tmpURL)
        let controller = UIActivityViewController(activityItems: [tmpURL], applicationActivities: nil)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?
            .rootViewController?
            .present(controller, animated: true)
    }
}

struct TaxMetricCard: View {
    var title: String
    var amount: Decimal
    var color: Color
    var note: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            Text(amount < 0 ? "-$\(abs(amount), format: .number.precision(.fractionLength(2)))" : "$\(amount, format: .number.precision(.fractionLength(2)))")
                .font(.subheadline.bold())
                .foregroundColor(color)
            Text(note)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding()
        .background(color.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct TaxEventRow: View {
    var event: TaxableEvent

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(event.asset)
                        .font(.caption.bold())
                        .foregroundColor(.white)
                    Text(event.isLongTerm ? "Long-term" : "Short-term")
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(event.isLongTerm ? Color.blue.opacity(0.15) : Color.orange.opacity(0.15))
                        .foregroundColor(event.isLongTerm ? .blue : .orange)
                        .clipShape(Capsule())
                }
                Text(event.disposalDate, style: .date)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(event.gainLossUSD >= 0 ? "+$\(event.gainLossUSD, format: .number.precision(.fractionLength(2)))" : "-$\(abs(event.gainLossUSD), format: .number.precision(.fractionLength(2)))")
                    .font(.caption.bold())
                    .foregroundColor(event.gainLossUSD >= 0 ? .red : .green)
                Text("Proceeds: $\(event.proceedsUSD, format: .number.precision(.fractionLength(2)))")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }
}
