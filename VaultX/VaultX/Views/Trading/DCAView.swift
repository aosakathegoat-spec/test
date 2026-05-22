import SwiftUI

struct DCAView: View {
    @StateObject private var dcaService = DCAService.shared
    @EnvironmentObject var walletManager: WalletManager
    @State private var showingCreatePlan = false

    var totalInvested: Decimal {
        dcaService.plans.reduce(0) { $0 + $1.totalInvested }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if dcaService.plans.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            summaryCard
                            ForEach(dcaService.plans) { plan in
                                DCAPlanCard(plan: plan)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Auto-Invest (DCA)")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCreatePlan = true
                    } label: {
                        Image(systemName: "plus.circle.fill").foregroundColor(.purple)
                    }
                }
            }
            .sheet(isPresented: $showingCreatePlan) {
                CreateDCAPlanView()
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { dcaService.loadPlans() }
    }

    private var summaryCard: some View {
        HStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("Total Invested").font(.caption).foregroundColor(.gray)
                Text("$\(totalInvested, format: .number.precision(.fractionLength(2)))").font(.title3.bold()).foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            Divider().background(Color.white.opacity(0.1)).frame(height: 36)
            VStack(spacing: 4) {
                Text("Active Plans").font(.caption).foregroundColor(.gray)
                Text("\(dcaService.plans.filter(\.isActive).count)").font(.title3.bold()).foregroundColor(.purple)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.clockwise.circle.fill")
                .font(.system(size: 60)).foregroundColor(.purple.opacity(0.5))
            Text("Auto-Invest").font(.title3.bold()).foregroundColor(.white)
            Text("Set up recurring crypto purchases with Dollar Cost Averaging — invest fixed amounts at regular intervals regardless of price")
                .font(.subheadline).foregroundColor(.gray).multilineTextAlignment(.center).padding(.horizontal)
            Button("Create First Plan") { showingCreatePlan = true }
                .buttonStyle(.borderedProminent).tint(.purple)
        }
    }
}

struct DCAPlanCard: View {
    var plan: DCAService.DCAPlan
    @StateObject private var dcaService = DCAService.shared

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(plan.toToken)
                            .font(.headline.bold()).foregroundColor(.white)
                        Text(plan.frequency.rawValue)
                            .font(.caption2.bold())
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.purple.opacity(0.15)).foregroundColor(.purple)
                            .clipShape(Capsule())
                        if !plan.isActive {
                            Text("Paused")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.orange.opacity(0.15)).foregroundColor(.orange)
                                .clipShape(Capsule())
                        }
                    }
                    Text("$\(plan.amount, format: .number.precision(.fractionLength(2))) per execution")
                        .font(.caption).foregroundColor(.gray)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("$\(plan.totalInvested, format: .number.precision(.fractionLength(2)))")
                        .font(.subheadline.bold()).foregroundColor(.white)
                    Text("invested").font(.caption2).foregroundColor(.gray)
                }
            }

            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "chart.line.uptrend.xyaxis").font(.caption)
                    Text("\(plan.executionCount) executions").font(.caption)
                }
                .foregroundColor(.gray)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "clock.fill").font(.caption)
                    Text("Next: \(plan.nextExecLabel)").font(.caption)
                }
                .foregroundColor(.blue)
            }

            if plan.averageCostBasis > 0 {
                HStack {
                    Text("Avg cost: $\(plan.averageCostBasis, format: .number.precision(.fractionLength(2)))")
                        .font(.caption).foregroundColor(.gray)
                    Spacer()
                    let roi = plan.averageROI
                    Text(roi >= 0 ? "+\(String(format: "%.1f", roi))% ROI" : "\(String(format: "%.1f", roi))% ROI")
                        .font(.caption.bold())
                        .foregroundColor(roi >= 0 ? .green : .red)
                }
            }

            HStack(spacing: 12) {
                Button(plan.isActive ? "Pause" : "Resume") {
                    if plan.isActive { dcaService.pausePlan(plan.id) }
                    else { dcaService.resumePlan(plan.id) }
                }
                .font(.caption.bold())
                .frame(maxWidth: .infinity, minHeight: 32)
                .background(Color.white.opacity(0.07))
                .foregroundColor(plan.isActive ? .orange : .green)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Button("Delete") { dcaService.deletePlan(plan.id) }
                    .font(.caption.bold())
                    .frame(maxWidth: .infinity, minHeight: 32)
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct CreateDCAPlanView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var walletManager: WalletManager
    @StateObject private var dcaService = DCAService.shared

    @State private var selectedCrypto = "BTC"
    @State private var amount = "100"
    @State private var frequency: DCAService.DCAPlan.Frequency = .weekly
    @State private var maxExecutions = ""
    @State private var unlimitedExecutions = true
    @State private var isCreating = false

    private let cryptos = ["BTC", "ETH", "SOL", "MATIC", "AVAX", "BNB", "LINK", "UNI"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        // Asset
                        FormSection(title: "Buy Asset") {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(cryptos, id: \.self) { c in
                                        Button(c) { selectedCrypto = c }
                                            .font(.subheadline.bold())
                                            .padding(.horizontal, 14).padding(.vertical, 8)
                                            .background(selectedCrypto == c ? Color.purple.opacity(0.3) : Color.white.opacity(0.07))
                                            .foregroundColor(selectedCrypto == c ? .purple : .gray)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }

                        // Amount
                        FormSection(title: "Amount (USDC per purchase)") {
                            HStack {
                                Image(systemName: "dollarsign.circle.fill").foregroundColor(.green)
                                TextField("100", text: $amount).keyboardType(.decimalPad)
                                    .font(.title2.bold()).foregroundColor(.white)
                            }
                            .padding()
                            .background(Color.white.opacity(0.07))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            // Quick amounts
                            HStack(spacing: 8) {
                                ForEach(["25", "50", "100", "250", "500"], id: \.self) { amt in
                                    Button(amt) { amount = amt }
                                        .font(.caption.bold())
                                        .padding(.horizontal, 10).padding(.vertical, 6)
                                        .background(amount == amt ? Color.green.opacity(0.2) : Color.white.opacity(0.07))
                                        .foregroundColor(amount == amt ? .green : .gray)
                                        .clipShape(Capsule())
                                }
                            }
                        }

                        // Frequency
                        FormSection(title: "Frequency") {
                            VStack(spacing: 8) {
                                ForEach(DCAService.DCAPlan.Frequency.allCases, id: \.self) { freq in
                                    Button(action: { frequency = freq }) {
                                        HStack {
                                            Image(systemName: freq.icon).foregroundColor(.purple)
                                            Text(freq.rawValue).font(.subheadline).foregroundColor(.white)
                                            Spacer()
                                            if frequency == freq {
                                                Image(systemName: "checkmark.circle.fill").foregroundColor(.purple)
                                            }
                                        }
                                        .padding()
                                        .background(frequency == freq ? Color.purple.opacity(0.1) : Color.white.opacity(0.05))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                }
                            }
                        }

                        // Projection
                        if let amt = Decimal(string: amount), amt > 0 {
                            let yearly = amt * 52  // roughly weekly
                            VStack(spacing: 8) {
                                Text("Annual investment: ~$\(yearly, format: .number.precision(.fractionLength(0)))")
                                    .font(.subheadline).foregroundColor(.gray)
                                Text("At \(selectedCrypto) prices, you'd buy approximately \(String(format: "%.4f", Double(truncating: yearly as NSDecimalNumber) / 67000)) \(selectedCrypto)/year")
                                    .font(.caption).foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color.purple.opacity(0.07))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Button(action: createPlan) {
                            if isCreating { ProgressView().tint(.white) }
                            else {
                                Label("Start Auto-Invest", systemImage: "arrow.clockwise.circle.fill")
                                    .font(.headline).foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .disabled(isCreating || amount.isEmpty)
                    }
                    .padding()
                }
            }
            .navigationTitle("New DCA Plan")
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }

    private func createPlan() {
        guard let wallet = walletManager.wallets.first,
              let amt = Decimal(string: amount) else { return }
        isCreating = true
        let _ = dcaService.createPlan(
            walletId: wallet.id,
            fromToken: "USDC",
            toToken: selectedCrypto,
            toChain: selectedCrypto == "SOL" ? .solana : .ethereum,
            amount: amt,
            frequency: frequency
        )
        isCreating = false
        dismiss()
    }
}
