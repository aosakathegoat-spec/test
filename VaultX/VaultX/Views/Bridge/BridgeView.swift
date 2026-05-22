import SwiftUI

struct BridgeView: View {
    @StateObject private var bridgeService = CrossChainBridgeService.shared
    @EnvironmentObject var walletManager: WalletManager

    @State private var fromChain: Chain = .ethereum
    @State private var toChain: Chain = .arbitrum
    @State private var token = "USDC"
    @State private var amount = ""
    @State private var quotes: [CrossChainBridgeService.BridgeQuote] = []
    @State private var selectedQuote: CrossChainBridgeService.BridgeQuote?
    @State private var isLoading = false
    @State private var isBridging = false
    @State private var showingConfirmation = false
    @State private var bridgeTx: CrossChainBridgeService.BridgeTransaction?
    @State private var errorMessage: String?
    @State private var activeTransactions: [CrossChainBridgeService.BridgeTransaction] = []

    private let popularTokens = ["USDC", "USDT", "ETH", "WBTC", "DAI", "MATIC", "BNB"]
    private let allChains: [Chain] = [.ethereum, .arbitrum, .optimism, .base, .polygon, .bsc, .avalanche, .fantom]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        chainSelector
                        tokenAmountSection
                        if !quotes.isEmpty { quotesSection }
                        if !activeTransactions.isEmpty { activeTransactionsSection }
                    }
                    .padding()
                }
            }
            .navigationTitle("Bridge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { refreshButton }
            .sheet(isPresented: $showingConfirmation) {
                if let quote = selectedQuote {
                    BridgeConfirmationView(quote: quote) { confirmed in
                        if confirmed { Task { await executeBridge() } }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: amount) { _ in Task { await fetchQuotes() } }
        .onChange(of: fromChain) { _ in Task { await fetchQuotes() } }
        .onChange(of: toChain) { _ in Task { await fetchQuotes() } }
        .onChange(of: token) { _ in Task { await fetchQuotes() } }
    }

    // MARK: - Chain Selector

    private var chainSelector: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                chainPicker(label: "From", selected: $fromChain, exclude: toChain)
                Button(action: swapChains) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.title3.bold())
                        .foregroundColor(.purple)
                        .padding(10)
                        .background(Color.purple.opacity(0.15))
                        .clipShape(Circle())
                }
                chainPicker(label: "To", selected: $toChain, exclude: fromChain)
            }
        }
    }

    private func chainPicker(label: String, selected: Binding<Chain>, exclude: Chain) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).foregroundColor(.gray)
            Menu {
                ForEach(allChains.filter { $0 != exclude }, id: \.self) { chain in
                    Button(chain.displayName) { selected.wrappedValue = chain }
                }
            } label: {
                HStack {
                    Image(systemName: selected.wrappedValue.symbolImage).foregroundColor(.purple)
                    Text(selected.wrappedValue.displayName).font(.subheadline.bold()).foregroundColor(.white)
                    Image(systemName: "chevron.down").font(.caption).foregroundColor(.gray)
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func swapChains() {
        let tmp = fromChain
        fromChain = toChain
        toChain = tmp
    }

    // MARK: - Token & Amount

    private var tokenAmountSection: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Token").font(.caption).foregroundColor(.gray)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(popularTokens, id: \.self) { t in
                            Button(t) { token = t }
                                .font(.caption.bold())
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(token == t ? Color.purple.opacity(0.3) : Color.white.opacity(0.07))
                                .foregroundColor(token == t ? .purple : .gray)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Amount").font(.caption).foregroundColor(.gray)
                HStack {
                    TextField("0.00", text: $amount)
                        .keyboardType(.decimalPad)
                        .font(.title2.bold()).foregroundColor(.white)
                    if isLoading { ProgressView().tint(.purple).scaleEffect(0.8) }
                }
                .padding()
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                HStack(spacing: 8) {
                    ForEach(["100", "500", "1000", "5000"], id: \.self) { amt in
                        Button(amt) { amount = amt }
                            .font(.caption.bold())
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(amount == amt ? Color.purple.opacity(0.2) : Color.white.opacity(0.07))
                            .foregroundColor(amount == amt ? .purple : .gray)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Quotes

    private var quotesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bridge Routes").font(.headline).foregroundColor(.white)
            ForEach(quotes) { quote in
                BridgeQuoteCard(quote: quote, isSelected: selectedQuote?.id == quote.id) {
                    selectedQuote = quote
                }
            }
            if let selected = selectedQuote {
                bridgeButton(quote: selected)
            }
        }
    }

    private func bridgeButton(quote: CrossChainBridgeService.BridgeQuote) -> some View {
        Button(action: { showingConfirmation = true }) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                Text("Bridge via \(quote.bridge.rawValue)")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Active Transactions

    private var activeTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Bridges").font(.headline).foregroundColor(.white)
            ForEach(activeTransactions) { tx in
                BridgeTxStatusCard(tx: tx)
            }
        }
    }

    // MARK: - Toolbar

    private var refreshButton: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: { Task { await fetchQuotes() } }) {
                Image(systemName: "arrow.clockwise").foregroundColor(.purple)
            }
        }
    }

    // MARK: - Actions

    private func fetchQuotes() async {
        guard let amt = Decimal(string: amount), amt > 0, fromChain != toChain else {
            quotes = []
            return
        }
        await MainActor.run { isLoading = true }
        let fetched = await bridgeService.getBridgeQuotes(fromChain: fromChain, toChain: toChain, token: token, amount: amt)
        await MainActor.run {
            quotes = fetched
            selectedQuote = fetched.first
            isLoading = false
        }
    }

    private func executeBridge() async {
        guard let quote = selectedQuote,
              let wallet = walletManager.wallets.first else { return }
        await MainActor.run { isBridging = true }
        do {
            let tx = try await bridgeService.executeBridge(quote: quote, wallet: wallet)
            await MainActor.run {
                activeTransactions.append(tx)
                bridgeTx = tx
                isBridging = false
                amount = ""
                quotes = []
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isBridging = false
            }
        }
    }
}

// MARK: - Bridge Quote Card

struct BridgeQuoteCard: View {
    var quote: CrossChainBridgeService.BridgeQuote
    var isSelected: Bool
    var onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(quote.bridge.rawValue)
                                .font(.subheadline.bold()).foregroundColor(.white)
                            if quote.isInstant {
                                Label("Instant", systemImage: "bolt.fill")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Color.green.opacity(0.15))
                                    .foregroundColor(.green)
                                    .clipShape(Capsule())
                            }
                        }
                        Text("\(quote.estimatedMinutes) min · \(quote.steps.count) steps")
                            .font(.caption).foregroundColor(.gray)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(quote.toAmount, format: .number.precision(.fractionLength(4))) \(quote.toToken)")
                            .font(.subheadline.bold()).foregroundColor(.green)
                        Text("Fee: $\(quote.totalFeeUSD, format: .number.precision(.fractionLength(2)))")
                            .font(.caption).foregroundColor(.orange)
                    }
                }

                HStack(spacing: 6) {
                    ForEach(quote.steps) { step in
                        HStack(spacing: 4) {
                            Circle().fill(Color.purple.opacity(0.5)).frame(width: 6, height: 6)
                            Text(step.description).font(.caption2).foregroundColor(.gray)
                        }
                        if step.id != quote.steps.last?.id {
                            Image(systemName: "arrow.right").font(.caption2).foregroundColor(.gray)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(isSelected ? Color.purple.opacity(0.12) : Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(isSelected ? Color.purple : Color.clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Bridge Tx Status Card

struct BridgeTxStatusCard: View {
    var tx: CrossChainBridgeService.BridgeTransaction

    var statusColor: Color {
        switch tx.status {
        case .pending: return .orange
        case .inFlight: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(statusColor.opacity(0.15)).frame(width: 44, height: 44)
                Image(systemName: tx.status == .completed ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                    .foregroundColor(statusColor)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("\(tx.fromChain.displayName) → \(tx.toChain.displayName)")
                    .font(.subheadline.bold()).foregroundColor(.white)
                Text("\(tx.amount, format: .number.precision(.fractionLength(4))) \(tx.token) via \(tx.bridge.rawValue)")
                    .font(.caption).foregroundColor(.gray)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(tx.status.rawValue)
                    .font(.caption.bold()).foregroundColor(statusColor)
                if let eta = tx.estimatedCompletionAt {
                    Text(eta, style: .relative)
                        .font(.caption2).foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Bridge Confirmation View

struct BridgeConfirmationView: View {
    @Environment(\.dismiss) private var dismiss
    var quote: CrossChainBridgeService.BridgeQuote
    var onConfirm: (Bool) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        confirmRow(label: "Bridge", value: quote.bridge.rawValue)
                        confirmRow(label: "From", value: "\(quote.fromChain.displayName)")
                        confirmRow(label: "To", value: "\(quote.toChain.displayName)")
                        confirmRow(label: "Send", value: "\(quote.fromAmount, format: .number.precision(.fractionLength(4))) \(quote.fromToken)")
                        confirmRow(label: "Receive", value: "\(quote.toAmount, format: .number.precision(.fractionLength(4))) \(quote.toToken)")
                        confirmRow(label: "Bridge Fee", value: "$\(quote.bridgeFeeUSD, format: .number.precision(.fractionLength(2)))")
                        confirmRow(label: "Dest Gas", value: "$\(quote.destinationGasUSD, format: .number.precision(.fractionLength(2)))")
                        confirmRow(label: "Est. Time", value: "\(quote.estimatedMinutes) minutes")
                        confirmRow(label: "Slippage", value: "\(String(format: "%.1f", quote.slippage))%")
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    Text("Face ID will be required to authorize this transaction")
                        .font(.caption).foregroundColor(.gray).multilineTextAlignment(.center)

                    Button(action: { onConfirm(true); dismiss() }) {
                        Label("Authorize Bridge", systemImage: "faceid")
                            .font(.headline).foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding()
            }
            .navigationTitle("Confirm Bridge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }

    private func confirmRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundColor(.gray)
            Spacer()
            Text(value).font(.subheadline.bold()).foregroundColor(.white)
        }
    }
}
