import SwiftUI
import SafariServices

struct BuyView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var walletManager: WalletManager

    @State private var fiatAmount = "100"
    @State private var selectedCrypto = "BTC"
    @State private var selectedFiatCurrency = "USD"
    @State private var selectedWallet: Wallet?
    @State private var quotes: [FiatOnRampService.OnRampQuote] = []
    @State private var selectedQuote: FiatOnRampService.OnRampQuote?
    @State private var isLoading = false
    @State private var showingWebView = false
    @State private var purchaseURL: URL?
    @State private var selectedPaymentMethod: FiatOnRampService.PaymentMethod = .creditCard

    private let onRamp = FiatOnRampService.shared
    private let cryptos = ["BTC", "ETH", "SOL", "USDC", "USDT", "BNB", "MATIC", "AVAX"]
    private let fiats = ["USD", "EUR", "GBP", "CAD", "AUD", "JPY"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        amountSection
                        paymentMethodPicker
                        quotesSection
                        if !quotes.isEmpty { bestDealBanner }
                        buyButton
                    }
                    .padding()
                }
            }
            .navigationTitle("Buy Crypto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingWebView) {
                if let url = purchaseURL {
                    SafariWebView(url: url)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task { await refreshQuotes() }
        .onChange(of: fiatAmount) { _ in
            Task { await refreshQuotes() }
        }
        .onChange(of: selectedCrypto) { _ in
            Task { await refreshQuotes() }
        }
    }

    // MARK: - Amount Section

    private var amountSection: some View {
        VStack(spacing: 16) {
            // Fiat input
            VStack(alignment: .leading, spacing: 8) {
                Text("You Pay")
                    .font(.subheadline.bold())
                    .foregroundColor(.gray)

                HStack(spacing: 12) {
                    Menu {
                        ForEach(fiats, id: \.self) { fiat in
                            Button(fiat) { selectedFiatCurrency = fiat }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedFiatCurrency)
                                .font(.headline)
                                .foregroundColor(.white)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    TextField("Amount", text: $fiatAmount)
                        .keyboardType(.decimalPad)
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .multilineTextAlignment(.trailing)
                }
                .padding()
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                // Quick amounts
                HStack(spacing: 8) {
                    ForEach(["50", "100", "250", "500", "1000"], id: \.self) { amount in
                        Button(amount) {
                            fiatAmount = amount
                        }
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(fiatAmount == amount ? Color.purple.opacity(0.3) : Color.white.opacity(0.07))
                        .foregroundColor(fiatAmount == amount ? .purple : .gray)
                        .clipShape(Capsule())
                    }
                }
            }

            // Crypto selector
            VStack(alignment: .leading, spacing: 8) {
                Text("You Receive")
                    .font(.subheadline.bold())
                    .foregroundColor(.gray)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(cryptos, id: \.self) { crypto in
                            Button(action: { selectedCrypto = crypto }) {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color.purple.opacity(0.3))
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Text(String(crypto.prefix(1)))
                                                .font(.caption2.bold())
                                                .foregroundColor(.purple)
                                        )
                                    Text(crypto)
                                        .font(.subheadline.bold())
                                        .foregroundColor(selectedCrypto == crypto ? .white : .gray)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selectedCrypto == crypto ? Color.purple.opacity(0.3) : Color.white.opacity(0.07))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(selectedCrypto == crypto ? Color.purple : Color.clear, lineWidth: 1.5)
                                )
                            }
                        }
                    }
                }
            }

            // Destination wallet
            VStack(alignment: .leading, spacing: 8) {
                Text("Destination Wallet")
                    .font(.subheadline.bold())
                    .foregroundColor(.gray)

                Menu {
                    ForEach(walletManager.wallets) { wallet in
                        Button(action: { selectedWallet = wallet }) {
                            Label(wallet.name, systemImage: wallet.chain.symbolImage)
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: (selectedWallet ?? walletManager.wallets.first)?.chain.symbolImage ?? "wallet.pass")
                            .foregroundColor(.purple)
                        Text((selectedWallet ?? walletManager.wallets.first)?.name ?? "Select wallet")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "chevron.down").foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // MARK: - Payment Method

    private var paymentMethodPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Payment Method")
                .font(.subheadline.bold())
                .foregroundColor(.gray)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(FiatOnRampService.PaymentMethod.allCases, id: \.self) { method in
                        Button(action: { selectedPaymentMethod = method }) {
                            HStack(spacing: 6) {
                                Image(systemName: method.icon)
                                    .font(.caption)
                                Text(method.rawValue)
                                    .font(.caption.bold())
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(selectedPaymentMethod == method ? Color.green.opacity(0.2) : Color.white.opacity(0.07))
                            .foregroundColor(selectedPaymentMethod == method ? .green : .gray)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(selectedPaymentMethod == method ? Color.green : Color.clear, lineWidth: 1))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Quotes

    private var quotesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Best Rates")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                if isLoading {
                    ProgressView().tint(.purple).scaleEffect(0.8)
                }
            }

            if quotes.isEmpty && !isLoading {
                Text("Enter an amount to see quotes")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(quotes) { quote in
                    OnRampQuoteCard(quote: quote, isSelected: selectedQuote?.id == quote.id) {
                        selectedQuote = quote
                    }
                }
            }
        }
    }

    private var bestDealBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundColor(.yellow)
            if let best = quotes.first {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Best Deal: \(best.provider.rawValue)")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                    Text("Save $\(quotes.last.map { String(format: "%.2f", Double(truncating: ($0.totalFeeUSD - best.totalFeeUSD) as NSDecimalNumber)) } ?? "0") vs highest fee provider")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                }
            }
            Spacer()
        }
        .padding()
        .background(Color.yellow.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.yellow.opacity(0.2), lineWidth: 1))
    }

    private var buyButton: some View {
        Button(action: startPurchase) {
            HStack {
                Image(systemName: "creditcard.fill")
                Text(selectedQuote.map { "Buy with \($0.provider.rawValue)" } ?? "Select a Provider")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                LinearGradient(colors: [.green, .teal], startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .disabled(selectedQuote == nil)
        .opacity(selectedQuote == nil ? 0.5 : 1)
    }

    private func refreshQuotes() async {
        guard let amount = Decimal(string: fiatAmount), amount > 0 else { quotes = []; return }
        let wallet = selectedWallet ?? walletManager.wallets.first
        guard let walletAddress = wallet?.address else { return }

        await MainActor.run { isLoading = true }

        let fetched = await onRamp.getQuotes(
            fiatAmount: amount,
            fiatCurrency: selectedFiatCurrency,
            cryptoSymbol: selectedCrypto,
            walletAddress: walletAddress
        )

        await MainActor.run {
            quotes = fetched
            selectedQuote = fetched.first
            isLoading = false
        }
    }

    private func startPurchase() {
        guard let quote = selectedQuote,
              let wallet = selectedWallet ?? walletManager.wallets.first,
              let amount = Decimal(string: fiatAmount)
        else { return }

        purchaseURL = onRamp.launchPurchase(
            provider: quote.provider,
            fiatAmount: amount,
            fiatCurrency: selectedFiatCurrency,
            crypto: selectedCrypto,
            walletAddress: wallet.address
        )
        showingWebView = purchaseURL != nil
    }
}

// MARK: - Quote Card

struct OnRampQuoteCard: View {
    var quote: FiatOnRampService.OnRampQuote
    var isSelected: Bool
    var onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: quote.provider.logoSystemImage)
                        .font(.title3)
                        .foregroundColor(.purple)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(quote.provider.rawValue)
                            .font(.subheadline.bold())
                            .foregroundColor(.white)

                        if quote.id == quote.id && isSelected {
                            Text("Selected")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .clipShape(Capsule())
                        }
                    }

                    HStack(spacing: 8) {
                        Text("\(quote.cryptoAmount, format: .number.precision(.fractionLength(6))) \(quote.cryptoSymbol)")
                            .font(.caption.bold())
                            .foregroundColor(.green)

                        Text("· \(quote.estimatedArrival)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Fee: $\(quote.totalFeeUSD, format: .number.precision(.fractionLength(2)))")
                        .font(.caption.bold())
                        .foregroundColor(quote.totalFeePercent < 1.5 ? .green : .orange)
                    Text(String(format: "%.2f%%", quote.totalFeePercent))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(isSelected ? Color.purple.opacity(0.12) : Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.purple : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Safari Web View

struct SafariWebView: UIViewControllerRepresentable {
    var url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        let vc = SFSafariViewController(url: url, configuration: config)
        vc.preferredBarTintColor = UIColor(Color.black)
        vc.preferredControlTintColor = UIColor(Color.purple)
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
