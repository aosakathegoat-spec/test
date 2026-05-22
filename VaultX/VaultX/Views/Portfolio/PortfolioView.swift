import SwiftUI
import Charts

struct PortfolioView: View {
    @StateObject private var portfolioService = PortfolioService.shared
    @State private var selectedTimeframe: Timeframe = .week
    @State private var showingTaxReport = false
    @State private var showingPriceAlerts = false

    enum Timeframe: String, CaseIterable {
        case day = "1D", week = "1W", month = "1M", threeMonths = "3M", year = "1Y", all = "ALL"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        portfolioHeader
                        timeframeSelector
                        portfolioChart
                        metricsCards
                        allocationSection
                        defiSection
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("Portfolio")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        showingPriceAlerts = true
                    } label: {
                        Image(systemName: "bell.fill")
                            .foregroundColor(portfolioService.priceAlerts.isEmpty ? .gray : .purple)
                    }

                    Button {
                        showingTaxReport = true
                    } label: {
                        Image(systemName: "doc.text.fill")
                    }
                }
            }
            .sheet(isPresented: $showingTaxReport) { TaxReportView() }
            .sheet(isPresented: $showingPriceAlerts) { PriceAlertsView() }
        }
    }

    // MARK: - Subviews

    private var portfolioHeader: some View {
        VStack(spacing: 8) {
            if let portfolio = portfolioService.portfolio {
                Text("Total Balance")
                    .font(.subheadline)
                    .foregroundColor(.gray)

                Text("$\(portfolio.totalValueUSD, format: .currency(code: "USD"))")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                HStack(spacing: 8) {
                    let change = portfolio.dayChange
                    let pct = portfolio.dayChangePercent
                    Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                    Text("\(change >= 0 ? "+" : "")\(change, format: .currency(code: "USD")) (\(String(format: "%.2f", pct))%)")
                }
                .font(.subheadline.bold())
                .foregroundColor(portfolio.dayChange >= 0 ? .green : .red)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    (portfolio.dayChange >= 0 ? Color.green : Color.red).opacity(0.15)
                )
                .clipShape(Capsule())
            } else {
                ProgressView()
                    .tint(.purple)
                    .frame(height: 80)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var timeframeSelector: some View {
        HStack(spacing: 0) {
            ForEach(Timeframe.allCases, id: \.self) { tf in
                Button(tf.rawValue) {
                    withAnimation { selectedTimeframe = tf }
                }
                .font(.caption.bold())
                .foregroundColor(selectedTimeframe == tf ? .white : .gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(selectedTimeframe == tf ? Color.purple : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var portfolioChart: some View {
        let snapshots = portfolioService.portfolio?.performanceHistory ?? []

        return Group {
            if #available(iOS 16.0, *), !snapshots.isEmpty {
                Chart(snapshots) { snapshot in
                    LineMark(
                        x: .value("Time", snapshot.timestamp),
                        y: .value("Value", snapshot.totalValueUSD)
                    )
                    .foregroundStyle(
                        LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
                    )
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    AreaMark(
                        x: .value("Time", snapshot.timestamp),
                        y: .value("Value", snapshot.totalValueUSD)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple.opacity(0.3), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .frame(height: 180)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 180)
                    .overlay(
                        Text("No history yet")
                            .foregroundColor(.gray)
                    )
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var metricsCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            if let portfolio = portfolioService.portfolio {
                MetricCard(
                    title: "Unrealized P&L",
                    value: "$\(abs(portfolio.unrealizedPnL))",
                    subtitle: String(format: "%.2f%%", portfolio.unrealizedPnLPercent),
                    color: portfolio.unrealizedPnL >= 0 ? .green : .red,
                    icon: "chart.line.uptrend.xyaxis"
                )
                MetricCard(
                    title: "Realized P&L",
                    value: "$\(abs(portfolio.realizedPnL))",
                    subtitle: "This year",
                    color: portfolio.realizedPnL >= 0 ? .green : .red,
                    icon: "checkmark.circle.fill"
                )
                let sharpe = portfolioService.calculateSharpeRatio(snapshots: portfolio.performanceHistory) ?? 0
                MetricCard(
                    title: "Sharpe Ratio",
                    value: String(format: "%.2f", sharpe),
                    subtitle: sharpe > 1 ? "Good" : sharpe > 0 ? "Fair" : "Poor",
                    color: sharpe > 1 ? .green : .yellow,
                    icon: "waveform.path.ecg"
                )
                let drawdown = portfolioService.calculateMaxDrawdown(snapshots: portfolio.performanceHistory)
                MetricCard(
                    title: "Max Drawdown",
                    value: String(format: "%.1f%%", drawdown * 100),
                    subtitle: "All time",
                    color: drawdown < 0.1 ? .green : drawdown < 0.3 ? .yellow : .red,
                    icon: "arrow.down.right"
                )
            }
        }
    }

    private var allocationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Allocation")
                .font(.headline)
                .foregroundColor(.white)

            let allocations = portfolioService.portfolio?.allocations ?? []

            ForEach(allocations.prefix(8)) { alloc in
                AllocationRow(allocation: alloc)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var defiSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("DeFi Positions")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text("$\(portfolioService.defiPositions.reduce(0) { $0 + $1.totalValueUSD }, format: .currency(code: "USD"))")
                    .font(.subheadline.bold())
                    .foregroundColor(.purple)
            }

            if portfolioService.defiPositions.isEmpty {
                Text("No DeFi positions found")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(portfolioService.defiPositions) { position in
                    DeFiPositionRow(position: position)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Supporting Views

struct MetricCard: View {
    var title: String
    var value: String
    var subtitle: String
    var color: Color
    var icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            Text(value)
                .font(.title3.bold())
                .foregroundColor(.white)
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(color)
        }
        .padding()
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

struct AllocationRow: View {
    var allocation: AssetAllocation

    var body: some View {
        HStack {
            Circle()
                .fill(Color.purple.opacity(0.3))
                .frame(width: 36, height: 36)
                .overlay(
                    Text(String(allocation.symbol.prefix(2)))
                        .font(.caption.bold())
                        .foregroundColor(.purple)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(allocation.symbol)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Text(allocation.chain.displayName)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("$\(allocation.usdValue, format: .number.precision(.fractionLength(2)))")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                HStack(spacing: 2) {
                    Image(systemName: allocation.priceChange24h >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption2)
                    Text(String(format: "%.2f%%", abs(allocation.priceChange24h)))
                        .font(.caption)
                }
                .foregroundColor(allocation.priceChange24h >= 0 ? .green : .red)
            }
        }
    }
}

struct DeFiPositionRow: View {
    var position: DeFiPosition

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(position.protocol_name)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Text(position.positionType.rawValue.capitalized)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(position.totalValueUSD, format: .number.precision(.fractionLength(2)))")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                if let apy = position.apy {
                    Text(String(format: "%.1f%% APY", apy))
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
