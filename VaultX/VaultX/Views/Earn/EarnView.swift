import SwiftUI

struct EarnView: View {
    @EnvironmentObject var walletManager: WalletManager
    @StateObject private var earnService = EarnService.shared
    @State private var selectedCategory: EarnService.EarnCategory? = nil
    @State private var selectedChain: Chain? = nil
    @State private var opportunities: [EarnService.EarnOpportunity] = []
    @State private var isLoading = true
    @State private var showingDeposit: EarnService.EarnOpportunity?
    @State private var showingYieldCalc = false

    var totalEarnedUSD: Decimal {
        earnService.activePositions.reduce(0) { $0 + $1.earnedRewards }
    }

    var totalLockedUSD: Decimal {
        earnService.activePositions.reduce(0) { $0 + $1.currentValue }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        earnSummaryCard
                        categoryFilter
                        if !earnService.activePositions.isEmpty {
                            activePositionsSection
                        }
                        opportunitiesSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Earn")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingYieldCalc = true
                    } label: {
                        Image(systemName: "function")
                            .foregroundColor(.purple)
                    }
                }
            }
            .sheet(item: $showingDeposit) { opp in
                EarnDepositView(opportunity: opp)
            }
            .sheet(isPresented: $showingYieldCalc) {
                YieldCalculatorView()
            }
        }
        .preferredColorScheme(.dark)
        .task { await loadOpportunities() }
    }

    // MARK: - Summary Card

    private var earnSummaryCard: some View {
        HStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("Locked")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text("$\(totalLockedUSD, format: .number.precision(.fractionLength(2)))")
                    .font(.title3.bold())
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)

            Divider().background(Color.white.opacity(0.1)).frame(height: 40)

            VStack(spacing: 6) {
                Text("Earned")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text("$\(totalEarnedUSD, format: .number.precision(.fractionLength(2)))")
                    .font(.title3.bold())
                    .foregroundColor(.green)
            }
            .frame(maxWidth: .infinity)

            Divider().background(Color.white.opacity(0.1)).frame(height: 40)

            VStack(spacing: 6) {
                Text("Positions")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text("\(earnService.activePositions.count)")
                    .font(.title3.bold())
                    .foregroundColor(.purple)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                FilterChip(label: "All", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                    Task { await loadOpportunities() }
                }

                ForEach(EarnService.EarnCategory.allCases, id: \.self) { cat in
                    FilterChip(label: cat.rawValue, isSelected: selectedCategory == cat) {
                        selectedCategory = cat == selectedCategory ? nil : cat
                        Task { await loadOpportunities() }
                    }
                }
            }
        }
    }

    // MARK: - Active Positions

    private var activePositionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Positions")
                .font(.headline)
                .foregroundColor(.white)

            ForEach(earnService.activePositions) { pos in
                ActivePositionCard(position: pos)
            }
        }
    }

    // MARK: - Opportunities

    private var opportunitiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Opportunities")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                if isLoading {
                    ProgressView().tint(.purple).scaleEffect(0.8)
                }
            }

            ForEach(opportunities) { opp in
                EarnOpportunityCard(opportunity: opp) {
                    showingDeposit = opp
                }
            }
        }
    }

    private func loadOpportunities() async {
        await MainActor.run { isLoading = true }
        let results = await EarnService.shared.fetchOpportunities()
        let filtered = selectedCategory == nil ? results : results.filter { $0.category == selectedCategory }
        await MainActor.run {
            opportunities = filtered
            isLoading = false
        }
    }
}

// MARK: - Opportunity Card

struct EarnOpportunityCard: View {
    var opportunity: EarnService.EarnOpportunity
    var onDeposit: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.purple.opacity(0.15)).frame(width: 44, height: 44)
                    Text(String(opportunity.protocol_name.prefix(2)))
                        .font(.subheadline.bold()).foregroundColor(.purple)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(opportunity.protocol_name)
                            .font(.subheadline.bold()).foregroundColor(.white)
                        CategoryBadge(category: opportunity.category)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: opportunity.chain.symbolImage).font(.caption2)
                        Text(opportunity.chain.displayName).font(.caption)
                        Text("·").font(.caption)
                        Text(opportunity.asset).font(.caption.bold())
                    }
                    .foregroundColor(.gray)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(opportunity.apyDisplay)
                        .font(.title3.bold())
                        .foregroundColor(.green)
                    Text("APY")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }

            HStack(spacing: 12) {
                // TVL
                VStack(alignment: .leading, spacing: 2) {
                    Text("TVL")
                        .font(.caption2).foregroundColor(.gray)
                    Text("$\(opportunity.tvlUSD / 1_000_000, format: .number.precision(.fractionLength(1)))M")
                        .font(.caption.bold()).foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Risk
                VStack(alignment: .leading, spacing: 2) {
                    Text("Risk")
                        .font(.caption2).foregroundColor(.gray)
                    Text(opportunity.risk.rawValue)
                        .font(.caption.bold())
                        .foregroundColor(opportunity.risk == .low ? .green : opportunity.risk == .medium ? .yellow : .red)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Lockup
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lockup")
                        .font(.caption2).foregroundColor(.gray)
                    Text(opportunity.lockupPeriod.rawValue)
                        .font(.caption.bold()).foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Audited
                if opportunity.isAudited {
                    VStack(alignment: .trailing, spacing: 2) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.caption).foregroundColor(.green)
                        Text("Audited").font(.caption2).foregroundColor(.green)
                    }
                }
            }

            HStack(spacing: 6) {
                ForEach(opportunity.rewards, id: \.self) { reward in
                    Text(reward)
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.15))
                        .foregroundColor(.green)
                        .clipShape(Capsule())
                }
                Spacer()
                Button("Deposit", action: onDeposit)
                    .font(.caption.bold())
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Active Position Card

struct ActivePositionCard: View {
    var position: EarnService.ActiveEarnPosition

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(position.protocolName)
                    .font(.subheadline.bold()).foregroundColor(.white)
                Text("\(position.asset) · \(position.category)")
                    .font(.caption).foregroundColor(.gray)
                Text("Since \(position.depositDate, style: .relative) ago")
                    .font(.caption2).foregroundColor(.gray)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(position.currentValue, format: .number.precision(.fractionLength(2)))")
                    .font(.subheadline.bold()).foregroundColor(.white)
                Text(position.roiPercent >= 0 ? "+\(String(format: "%.2f", position.roiPercent))%" : "\(String(format: "%.2f", position.roiPercent))%")
                    .font(.caption.bold())
                    .foregroundColor(position.roiPercent >= 0 ? .green : .red)
                Text(String(format: "%.1f%% APY", position.apy))
                    .font(.caption2).foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.green.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.green.opacity(0.15), lineWidth: 1))
    }
}

// MARK: - Earn Deposit View

struct EarnDepositView: View {
    var opportunity: EarnService.EarnOpportunity
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var walletManager: WalletManager
    @State private var amount = ""
    @State private var isDepositing = false
    @State private var projectedAnnual: Decimal = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 24) {
                    // Protocol header
                    VStack(spacing: 8) {
                        Text(opportunity.protocol_name)
                            .font(.title2.bold()).foregroundColor(.white)
                        Text(opportunity.apyDisplay + " APY · " + opportunity.asset)
                            .font(.subheadline).foregroundColor(.green)
                    }

                    // Amount input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Amount to Deposit")
                            .font(.subheadline.bold()).foregroundColor(.gray)
                        HStack {
                            TextField("0.00", text: $amount)
                                .keyboardType(.decimalPad)
                                .font(.title2.bold()).foregroundColor(.white)
                            Text(opportunity.asset)
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .onChange(of: amount) { val in
                            let amt = Decimal(string: val) ?? 0
                            projectedAnnual = EarnService.shared.calculateProjectedEarnings(
                                amount: amt, apy: opportunity.apy, days: 365
                            )
                        }
                    }

                    // Projection
                    if !amount.isEmpty {
                        VStack(spacing: 8) {
                            Text("Projected Annual Earnings")
                                .font(.caption).foregroundColor(.gray)
                            Text("+$\(projectedAnnual, format: .number.precision(.fractionLength(2)))")
                                .font(.title3.bold()).foregroundColor(.green)
                            Text("at current \(String(format: "%.1f", opportunity.apy))% APY")
                                .font(.caption2).foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Risk disclosure
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "info.circle.fill").foregroundColor(.blue)
                            Text("Risk Information").font(.caption.bold()).foregroundColor(.white)
                        }
                        Text(opportunity.description).font(.caption).foregroundColor(.gray)
                        if opportunity.isAudited {
                            Text("Audited by: " + opportunity.auditors.joined(separator: ", "))
                                .font(.caption2).foregroundColor(.green)
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Spacer()

                    Button(action: deposit) {
                        if isDepositing {
                            ProgressView().tint(.white)
                        } else {
                            Label("Deposit \(amount) \(opportunity.asset)", systemImage: "arrow.down.circle.fill")
                                .font(.headline).foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(LinearGradient(colors: [.green, .teal], startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .disabled(isDepositing || amount.isEmpty)
                }
                .padding()
            }
            .navigationTitle("Deposit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }

    private func deposit() {
        guard let wallet = walletManager.wallets.first,
              let amt = Decimal(string: amount) else { return }
        isDepositing = true
        Task {
            do {
                let _ = try await EarnService.shared.deposit(opportunity: opportunity, amount: amt, wallet: wallet)
                await MainActor.run { isDepositing = false; dismiss() }
            } catch {
                await MainActor.run { isDepositing = false }
            }
        }
    }
}

// MARK: - Yield Calculator

struct YieldCalculatorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var principal: Double = 1000
    @State private var apy: Double = 5.0
    @State private var years: Double = 1

    var projectedValue: Double {
        principal * pow(1 + apy / 100, years)
    }

    var totalEarned: Double { projectedValue - principal }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 28) {
                    VStack(spacing: 6) {
                        Text("$\(Int(projectedValue).formatted())")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                        Text("+$\(Int(totalEarned).formatted()) earned")
                            .font(.subheadline).foregroundColor(.gray)
                    }
                    .padding(.top)

                    VStack(spacing: 20) {
                        SliderRow(label: "Principal", value: $principal, range: 100...100_000, format: "$%.0f")
                        SliderRow(label: "APY", value: $apy, range: 0.1...50.0, format: "%.1f%%")
                        SliderRow(label: "Duration", value: $years, range: 0.25...10.0, format: "%.2f years")
                    }
                }
                .padding()
            }
            .navigationTitle("Yield Calculator")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }
}

struct SliderRow: View {
    var label: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var format: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label).font(.subheadline).foregroundColor(.gray)
                Spacer()
                Text(String(format: format, value)).font(.subheadline.bold()).foregroundColor(.white)
            }
            Slider(value: $value, in: range).tint(.purple)
        }
    }
}

// MARK: - Helpers

struct CategoryBadge: View {
    var category: EarnService.EarnCategory

    var color: Color {
        switch category {
        case .staking, .liquidStake: return .blue
        case .lending: return .green
        case .lpFarming: return .purple
        case .vault: return .orange
        case .savings: return .teal
        }
    }

    var body: some View {
        Text(category.rawValue)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}

struct FilterChip: View {
    var label: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSelected ? Color.purple.opacity(0.3) : Color.white.opacity(0.07))
                .foregroundColor(isSelected ? .purple : .gray)
                .clipShape(Capsule())
        }
    }
}
