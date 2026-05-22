import SwiftUI
import SafariServices

struct SellView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var walletManager: WalletManager

    @State private var cryptoAmount = "0.01"
    @State private var selectedCrypto = "BTC"
    @State private var selectedFiatCurrency = "USD"
    @State private var selectedWallet: Wallet?
    @State private var sellQuotes: [FiatOnRampService.SellQuote] = []
    @State private var selectedQuote: FiatOnRampService.SellQuote?
    @State private var isLoading = false
    @State private var showingWebView = false
    @State private var sellURL: URL?
    @State private var bankAccount = ""
    @State private var payoutMethod: PayoutMethod = .bankTransfer

    private let offRamp = FiatOnRampService.shared
    private let cryptos = ["BTC", "ETH", "SOL", "USDC", "USDT", "BNB", "MATIC"]
    private let fiats = ["USD", "EUR", "GBP", "CAD", "AUD"]

    enum PayoutMethod: String, CaseIterable {
        case bankTransfer = "Bank Transfer"
        case paypal = "PayPal"
        case applePay = "Apple Pay"
        case sepa = "SEPA"

        var icon: String {
            switch self {
            case .bankTransfer: return "building.columns.fill"
            case .paypal: return "p.circle.fill"
            case .applePay: return "apple.logo"
            case .sepa: return "eurosign.circle.fill"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        sellAmountSection
                        payoutMethodPicker
                        sellQuotesSection
                        if !sellQuotes.isEmpty { taxWarning }
                        sellButton
                    }
                    .padding()
                }
            }
            .navigationTitle("Sell Crypto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingWebView) {
                if let url = sellURL { SafariWebView(url: url) }
            }
        }
        .preferredColorScheme(.dark)
        .task { await refreshSellQuotes() }
        .onChange(of: cryptoAmount) { _ in Task { await refreshSellQuotes() } }
        .onChange(of: selectedCrypto) { _ in Task { await refreshSellQuotes() } }
        .onChange(of: selectedFiatCurrency) { _ in Task { await refreshSellQuotes() } }
    }

    // MARK: - Sell Amount Section

    private var sellAmountSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("You Sell").font(.subheadline.bold()).foregroundColor(.gray)
                HStack(spacing: 12) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(cryptos, id: \.self) { c in
                                Button(c) { selectedCrypto = c }
                                    .font(.caption.bold())
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(selectedCrypto == c ? Color.purple.opacity(0.3) : Color.white.opacity(0.07))
                                    .foregroundColor(selectedCrypto == c ? .purple : .gray)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                HStack {
                    TextField("0.01", text: $cryptoAmount)
                        .keyboardType(.decimalPad)
                        .font(.title2.bold()).foregroundColor(.white)
                    Text(selectedCrypto).font(.subheadline).foregroundColor(.gray)
                    if isLoading { ProgressView().tint(.purple).scaleEffect(0.8) }
                }
                .padding()
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                if let wallet = selectedWallet ?? walletManager.wallets.first(where: { $0.chain.nativeCurrency == selectedCrypto || selectedCrypto == "BTC" && $0.chain == .bitcoin }) {
                    HStack {
                        Text("Available: \(wallet.balance?.nativeAmount ?? 0, format: .number.precision(.fractionLength(6))) \(selectedCrypto)")
                            .font(.caption).foregroundColor(.gray)
                        Spacer()
                        Button("Max") {
                            if let native = wallet.balance?.nativeAmount {
                                cryptoAmount = String(format: "%.6f", Double(truncating: native as NSDecimalNumber))
                            }
                        }
                        .font(.caption.bold()).foregroundColor(.purple)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Receive Currency").font(.subheadline.bold()).foregroundColor(.gray)
                HStack(spacing: 8) {
                    ForEach(fiats, id: \.self) { fiat in
                        Button(fiat) { selectedFiatCurrency = fiat }
                            .font(.caption.bold())
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(selectedFiatCurrency == fiat ? Color.green.opacity(0.25) : Color.white.opacity(0.07))
                            .foregroundColor(selectedFiatCurrency == fiat ? .green : .gray)
                            .clipShape(Capsule())
                    }
                }
            }

            sourceWalletPicker
        }
    }

    private var sourceWalletPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Source Wallet").font(.subheadline.bold()).foregroundColor(.gray)
            Menu {
                ForEach(walletManager.wallets) { wallet in
                    Button(action: { selectedWallet = wallet }) {
                        Label(wallet.name, systemImage: wallet.chain.symbolImage)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: (selectedWallet ?? walletManager.wallets.first)?.chain.symbolImage ?? "wallet.pass").foregroundColor(.purple)
                    Text((selectedWallet ?? walletManager.wallets.first)?.name ?? "Select wallet").font(.subheadline).foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.down").foregroundColor(.gray)
                }
                .padding()
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Payout Method

    private var payoutMethodPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Payout Method").font(.subheadline.bold()).foregroundColor(.gray)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(PayoutMethod.allCases, id: \.self) { method in
                        Button(action: { payoutMethod = method }) {
                            HStack(spacing: 6) {
                                Image(systemName: method.icon).font(.caption)
                                Text(method.rawValue).font(.caption.bold())
                            }
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .background(payoutMethod == method ? Color.blue.opacity(0.2) : Color.white.opacity(0.07))
                            .foregroundColor(payoutMethod == method ? .blue : .gray)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(payoutMethod == method ? Color.blue : Color.clear, lineWidth: 1))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Sell Quotes

    private var sellQuotesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Best Offers").font(.headline).foregroundColor(.white)
                Spacer()
                if isLoading { ProgressView().tint(.purple).scaleEffect(0.8) }
            }

            if sellQuotes.isEmpty && !isLoading {
                Text("Enter an amount to see offers")
                    .font(.subheadline).foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center).padding()
            } else {
                ForEach(sellQuotes) { quote in
                    SellQuoteCard(quote: quote, isSelected: selectedQuote?.id == quote.id) {
                        selectedQuote = quote
                    }
                }
            }
        }
    }

    // MARK: - Tax Warning

    private var taxWarning: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.text.fill").foregroundColor(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text("Tax Reporting Required").font(.caption.bold()).foregroundColor(.white)
                Text("Selling crypto may trigger capital gains. Use the Tax tab to calculate obligations.")
                    .font(.caption2).foregroundColor(.yellow.opacity(0.8))
            }
        }
        .padding()
        .background(Color.yellow.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.yellow.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Sell Button

    private var sellButton: some View {
        Button(action: startSell) {
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                Text(selectedQuote.map { "Sell via \($0.provider.rawValue)" } ?? "Select a Provider")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .disabled(selectedQuote == nil)
        .opacity(selectedQuote == nil ? 0.5 : 1)
    }

    // MARK: - Actions

    private func refreshSellQuotes() async {
        guard let amt = Decimal(string: cryptoAmount), amt > 0 else { sellQuotes = []; return }
        await MainActor.run { isLoading = true }
        let fetched = await offRamp.getSellQuotes(
            cryptoAmount: amt,
            cryptoSymbol: selectedCrypto,
            fiatCurrency: selectedFiatCurrency,
            walletAddress: (selectedWallet ?? walletManager.wallets.first)?.address ?? ""
        )
        await MainActor.run {
            sellQuotes = fetched
            selectedQuote = fetched.first
            isLoading = false
        }
    }

    private func startSell() {
        guard let quote = selectedQuote,
              let wallet = selectedWallet ?? walletManager.wallets.first,
              let amt = Decimal(string: cryptoAmount)
        else { return }
        sellURL = offRamp.launchSell(
            provider: quote.provider,
            cryptoAmount: amt,
            cryptoSymbol: selectedCrypto,
            fiatCurrency: selectedFiatCurrency,
            walletAddress: wallet.address
        )
        showingWebView = sellURL != nil
    }
}

// MARK: - Sell Quote Card

struct SellQuoteCard: View {
    var quote: FiatOnRampService.SellQuote
    var isSelected: Bool
    var onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.orange.opacity(0.15)).frame(width: 44, height: 44)
                    Image(systemName: quote.provider.logoSystemImage).font(.title3).foregroundColor(.orange)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(quote.provider.rawValue).font(.subheadline.bold()).foregroundColor(.white)
                        if isSelected {
                            Text("Selected")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .foregroundColor(.orange)
                                .clipShape(Capsule())
                        }
                    }
                    HStack(spacing: 8) {
                        Text("\(quote.fiatAmount, format: .number.precision(.fractionLength(2))) \(quote.fiatCurrency)")
                            .font(.caption.bold()).foregroundColor(.green)
                        Text("· \(quote.estimatedArrival)")
                            .font(.caption).foregroundColor(.gray)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Fee: $\(quote.totalFeeUSD, format: .number.precision(.fractionLength(2)))")
                        .font(.caption.bold()).foregroundColor(quote.totalFeePercent < 1.5 ? .green : .orange)
                    Text(String(format: "%.2f%%", quote.totalFeePercent)).font(.caption2).foregroundColor(.gray)
                }
            }
            .padding()
            .background(isSelected ? Color.orange.opacity(0.1) : Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(isSelected ? Color.orange : Color.clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }
}
