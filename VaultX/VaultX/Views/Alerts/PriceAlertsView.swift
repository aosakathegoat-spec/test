import SwiftUI

struct PriceAlertsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var portfolioService = PortfolioService.shared
    @State private var showingCreateAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if portfolioService.priceAlerts.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(portfolioService.priceAlerts) { alert in
                            PriceAlertRow(alert: alert)
                                .listRowBackground(Color.white.opacity(0.05))
                        }
                        .onDelete { indices in
                            portfolioService.priceAlerts.remove(atOffsets: indices)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Price Alerts")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCreateAlert = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.purple)
                    }
                }
            }
            .sheet(isPresented: $showingCreateAlert) { CreatePriceAlertView() }
        }
        .preferredColorScheme(.dark)
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 60))
                .foregroundColor(.purple.opacity(0.5))
            Text("No Price Alerts")
                .font(.title3.bold())
                .foregroundColor(.white)
            Text("Set alerts to be notified when assets reach your target price")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Create Alert") { showingCreateAlert = true }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
        }
    }
}

struct PriceAlertRow: View {
    var alert: PriceAlert

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(alert.symbol)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Text(alert.alertType.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.15))
                        .foregroundColor(.purple)
                        .clipShape(Capsule())
                }
                Text("Target: $\(alert.targetPrice, format: .number.precision(.fractionLength(2)))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Spacer()
            VStack(alignment: .trailing) {
                if alert.isTriggered {
                    Text("Triggered")
                        .font(.caption.bold())
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "bell.fill")
                        .foregroundColor(alert.isActive ? .purple : .gray)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct CreatePriceAlertView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var portfolioService = PortfolioService.shared
    @State private var symbol = "BTC"
    @State private var alertType: PriceAlert.AlertType = .priceAbove
    @State private var targetPrice = ""
    @State private var repeatAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                Form {
                    Section {
                        HStack {
                            Text("Asset")
                                .foregroundColor(.gray)
                            Spacer()
                            TextField("BTC, ETH, SOL...", text: $symbol)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.trailing)
                                .textInputAutocapitalization(.characters)
                        }
                        .listRowBackground(Color.white.opacity(0.05))

                        Picker("Alert Type", selection: $alertType) {
                            Text("Price Above").tag(PriceAlert.AlertType.priceAbove)
                            Text("Price Below").tag(PriceAlert.AlertType.priceBelow)
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.white.opacity(0.05))

                        HStack {
                            Text("Target Price (USD)")
                                .foregroundColor(.gray)
                            Spacer()
                            TextField("0.00", text: $targetPrice)
                                .keyboardType(.decimalPad)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.trailing)
                        }
                        .listRowBackground(Color.white.opacity(0.05))

                        Toggle("Repeat Alert", isOn: $repeatAlert)
                            .tint(.purple)
                            .listRowBackground(Color.white.opacity(0.05))
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("New Price Alert")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        if let price = Decimal(string: targetPrice) {
                            portfolioService.createPriceAlert(
                                symbol: symbol.uppercased(),
                                chain: .ethereum,
                                alertType: alertType,
                                targetPrice: price,
                                repeat: repeatAlert
                            )
                            dismiss()
                        }
                    }
                    .disabled(symbol.isEmpty || targetPrice.isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
