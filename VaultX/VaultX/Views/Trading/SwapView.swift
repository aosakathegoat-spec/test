import SwiftUI

struct SwapView: View {
    @EnvironmentObject var walletManager: WalletManager
    @Environment(\.dismiss) private var dismiss

    @State private var fromToken: SwapAggregatorService.SwapToken?
    @State private var toToken: SwapAggregatorService.SwapToken?
    @State private var fromAmount = ""
    @State private var selectedChain: Chain = .ethereum
    @State private var quotes: [SwapAggregatorService.SwapQuote] = []
    @State private var bestQuote: SwapAggregatorService.SwapQuote?
    @State private var isLoadingQuotes = false
    @State private var slippage = 0.5
    @State private var showingSlippageSettings = false
    @State private var showingConfirmation = false
    @State private var showingMEVInfo = false
    @State private var mevEnabled = true
    @State private var isSwapping = false
    @State private var txHash: String?
    @State private var simulationResult: AdvancedSecurityService.SimulationResult?

    private let swapper = SwapAggregatorService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        chainSelector
                        swapCard
                        if let best = bestQuote {
                            bestRateCard(quote: best)
                            routeBreakdown(quote: best)
                            allQuotesSection
                        }
                        mevProtectionToggle
                        simulationCard
                        swapButton
                    }
                    .padding()
                }
            }
            .navigationTitle("Swap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSlippageSettings = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "slider.horizontal.3")
                            Text("\(slippage, specifier: "%.1f")%")
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.07))
                        .clipShape(Capsule())
                        .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showingSlippageSettings) { SlippageSettingsView(slippage: $slippage) }
            .sheet(isPresented: $showingConfirmation) {
                if let quote = bestQuote, let wallet = walletManager.wallets.first {
                    SwapConfirmationView(quote: quote, wallet: wallet) { hash in
                        txHash = hash
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { setupDefaultTokens() }
        .onChange(of: fromAmount) { _ in fetchQuotes() }
        .onChange(of: fromToken?.address) { _ in fetchQuotes() }
        .onChange(of: toToken?.address) { _ in fetchQuotes() }
    }

    // MARK: - Chain Selector

    private var chainSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Chain.allCases.filter { $0 != .bitcoinTestnet }) { chain in
                    Button(action: {
                        selectedChain = chain
                        setupDefaultTokens()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: chain.symbolImage)
                                .font(.caption)
                            Text(chain.displayName)
                                .font(.caption.bold())
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(selectedChain == chain ? Color.purple.opacity(0.3) : Color.white.opacity(0.07))
                        .foregroundColor(selectedChain == chain ? .purple : .gray)
                        .clipShape(Capsule())
                    }
                }
            }
        }
    }

    // MARK: - Swap Card

    private var swapCard: some View {
        VStack(spacing: 4) {
            // From token
            TokenInputCard(
                label: "From",
                token: $fromToken,
                amount: $fromAmount,
                availableTokens: swapper.popularTokens(chain: selectedChain),
                showBalance: true
            )

            // Swap direction button
            Button {
                let tmp = fromToken
                fromToken = toToken
                toToken = tmp
                if let toAmt = bestQuote.map({ String(format: "%.6f", Double(truncating: $0.toAmount as NSDecimalNumber)) }) {
                    fromAmount = toAmt
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 44, height: 44)
                    Circle()
                        .fill(Color.purple.opacity(0.2))
                        .frame(width: 40, height: 40)
                    Image(systemName: "arrow.up.arrow.down")
                        .foregroundColor(.purple)
                        .font(.subheadline.bold())
                }
            }
            .zIndex(1)

            // To token
            TokenInputCard(
                label: "To (estimated)",
                token: $toToken,
                amount: .constant(bestQuote.map { String(format: "%.6f", Double(truncating: $0.toAmount as NSDecimalNumber)) } ?? ""),
                availableTokens: swapper.popularTokens(chain: selectedChain),
                isReadOnly: true,
                showBalance: false
            )
        }
        .padding()
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Best Rate Card

    private func bestRateCard(quote: SwapAggregatorService.SwapQuote) -> some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Best Rate via \(quote.aggregator.rawValue)")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)

                    let rate = String(format: "1 %@ = %.4f %@", quote.fromToken.symbol, Double(truncating: quote.exchangeRate as NSDecimalNumber), quote.toToken.symbol)
                    Text(rate)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
                if isLoadingQuotes {
                    ProgressView().tint(.purple).scaleEffect(0.8)
                } else {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(String(format: "%.2f%% impact", quote.priceImpactPercent))
                            .font(.caption.bold())
                            .foregroundColor(quote.priceImpactPercent < 0.5 ? .green : quote.priceImpactPercent < 2 ? .yellow : .red)
                        Text("$\(quote.totalFeeUSD, format: .number.precision(.fractionLength(2))) fee")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }

            if quote.priceImpactPercent > 3 {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                    Text("High price impact (\(String(format: "%.2f", quote.priceImpactPercent))%). Consider splitting your order.")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(8)
                .background(Color.orange.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(Color.green.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.green.opacity(0.15), lineWidth: 1))
    }

    // MARK: - Route Breakdown

    private func routeBreakdown(quote: SwapAggregatorService.SwapQuote) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Route")
                .font(.caption.bold())
                .foregroundColor(.gray)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Text(quote.fromToken.symbol)
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.purple.opacity(0.2))
                        .foregroundColor(.purple)
                        .clipShape(Capsule())

                    ForEach(quote.route) { hop in
                        Image(systemName: "arrow.right").font(.caption).foregroundColor(.gray)
                        VStack(spacing: 2) {
                            Text(hop.poolName)
                                .font(.caption2.bold())
                                .foregroundColor(.white)
                            Text("\(Int(hop.percent))%")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    Image(systemName: "arrow.right").font(.caption).foregroundColor(.gray)
                    Text(quote.toToken.symbol)
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .clipShape(Capsule())
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - All Quotes

    private var allQuotesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("All Quotes — \(quotes.count) sources")
                .font(.caption.bold())
                .foregroundColor(.gray)

            ForEach(Array(quotes.enumerated()), id: \.element.id) { i, quote in
                HStack {
                    Text(quote.aggregator.rawValue)
                        .font(.caption.bold())
                        .foregroundColor(i == 0 ? .green : .white)

                    Spacer()

                    Text("\(quote.toAmount, format: .number.precision(.fractionLength(4))) \(quote.toToken.symbol)")
                        .font(.caption.bold())
                        .foregroundColor(i == 0 ? .green : .gray)

                    if i == 0 {
                        Text("BEST")
                            .font(.caption2.bold())
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .clipShape(Capsule())
                    } else if let best = quotes.first {
                        let diff = Double(truncating: ((best.toAmount - quote.toAmount) / best.toAmount * 100) as NSDecimalNumber)
                        Text(String(format: "-%.2f%%", diff))
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(i == 0 ? Color.green.opacity(0.05) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - MEV Protection Toggle

    private var mevProtectionToggle: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.orange.opacity(0.15)).frame(width: 40, height: 40)
                Image(systemName: "shield.lefthalf.filled").foregroundColor(.orange)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("MEV Protection")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Text(mevEnabled ? "Routing via Flashbots — front-running blocked" : "Exposed to sandwich attacks")
                    .font(.caption)
                    .foregroundColor(mevEnabled ? .green : .orange)
            }
            Spacer()
            Toggle("", isOn: $mevEnabled).tint(.purple)
        }
        .padding()
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Simulation Card

    private var simulationCard: some View {
        Group {
            if let sim = simulationResult {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: sim.isHighRisk ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .foregroundColor(sim.isHighRisk ? .red : .green)
                        Text(sim.isHighRisk ? "Simulation Found Issues" : "Simulation Passed")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                    }

                    ForEach(sim.riskFlags, id: \.self) { flag in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "xmark.circle.fill").font(.caption).foregroundColor(.red)
                            Text(flag).font(.caption).foregroundColor(.red)
                        }
                    }

                    ForEach(sim.approvals) { approval in
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill").font(.caption).foregroundColor(.orange)
                            Text(approval.isUnlimited ? "Unlimited \(approval.tokenSymbol) approval to \(approval.spender.prefix(8))..." : "Approve \(approval.amount) \(approval.tokenSymbol)")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding()
                .background(sim.isHighRisk ? Color.red.opacity(0.07) : Color.green.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    // MARK: - Swap Button

    private var swapButton: some View {
        Button(action: {
            if bestQuote != nil { showingConfirmation = true }
        }) {
            if isSwapping {
                ProgressView().tint(.white)
            } else {
                HStack {
                    Image(systemName: "arrow.2.squarepath")
                    Text(bestQuote == nil ? "Enter Amount to Swap" : "Swap Now")
                        .font(.headline)
                }
                .foregroundColor(.white)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(
            bestQuote == nil
                ? AnyShapeStyle(Color.gray.opacity(0.3))
                : AnyShapeStyle(LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing))
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .disabled(bestQuote == nil || isSwapping)
    }

    // MARK: - Helpers

    private func setupDefaultTokens() {
        let tokens = swapper.popularTokens(chain: selectedChain)
        fromToken = tokens.first
        toToken = tokens.dropFirst().first
    }

    private func fetchQuotes() {
        guard let from = fromToken, let to = toToken,
              let amount = Decimal(string: fromAmount), amount > 0 else {
            quotes = []
            bestQuote = nil
            return
        }

        Task {
            await MainActor.run { isLoadingQuotes = true }
            let fetched = await swapper.getQuotes(
                fromToken: from, toToken: to,
                fromAmount: amount, slippage: slippage,
                chain: selectedChain
            )
            await MainActor.run {
                quotes = fetched
                bestQuote = fetched.first
                isLoadingQuotes = false
            }

            // Run simulation
            if let best = fetched.first, let walletAddr = walletManager.wallets.first?.address {
                let sim = await AdvancedSecurityService.shared.simulateTransaction(
                    from: walletAddr, to: best.spenderAddress ?? "",
                    value: amount, data: best.calldata, chain: selectedChain
                )
                await MainActor.run { simulationResult = sim }
            }
        }
    }
}

// MARK: - Token Input Card

struct TokenInputCard: View {
    var label: String
    @Binding var token: SwapAggregatorService.SwapToken?
    @Binding var amount: String
    var availableTokens: [SwapAggregatorService.SwapToken]
    var isReadOnly: Bool = false
    var showBalance: Bool = true

    @State private var showingTokenPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label).font(.caption).foregroundColor(.gray)

            HStack(spacing: 12) {
                Button { showingTokenPicker = true } label: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.purple.opacity(0.2))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Text(token.map { String($0.symbol.prefix(2)) } ?? "?")
                                    .font(.caption2.bold())
                                    .foregroundColor(.purple)
                            )
                        Text(token?.symbol ?? "Select")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
                }

                Spacer()

                if isReadOnly {
                    Text(amount.isEmpty ? "0.0" : amount)
                        .font(.title3.bold())
                        .foregroundColor(amount.isEmpty ? .gray : .white)
                } else {
                    TextField("0.0", text: $amount)
                        .keyboardType(.decimalPad)
                        .font(.title3.bold())
                        .foregroundColor(.white)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .sheet(isPresented: $showingTokenPicker) {
            TokenPickerView(tokens: availableTokens, selected: $token)
        }
    }
}

struct TokenPickerView: View {
    var tokens: [SwapAggregatorService.SwapToken]
    @Binding var selected: SwapAggregatorService.SwapToken?
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    var filtered: [SwapAggregatorService.SwapToken] {
        search.isEmpty ? tokens : tokens.filter {
            $0.symbol.localizedCaseInsensitiveContains(search) || $0.name.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                List(filtered, id: \.address) { token in
                    Button(action: { selected = token; dismiss() }) {
                        HStack {
                            Circle().fill(Color.purple.opacity(0.2)).frame(width: 40, height: 40)
                                .overlay(Text(String(token.symbol.prefix(2))).font(.caption.bold()).foregroundColor(.purple))
                            VStack(alignment: .leading) {
                                Text(token.symbol).font(.subheadline.bold()).foregroundColor(.white)
                                Text(token.name).font(.caption).foregroundColor(.gray)
                            }
                            Spacer()
                            if let price = token.usdPrice {
                                Text("$\(price, format: .number.precision(.fractionLength(2)))").font(.caption).foregroundColor(.gray)
                            }
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.04))
                }
                .scrollContentBackground(.hidden)
                .searchable(text: $search, prompt: "Search tokens")
            }
            .navigationTitle("Select Token")
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Slippage Settings

struct SlippageSettingsView: View {
    @Binding var slippage: Double
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 24) {
                    HStack {
                        ForEach([0.1, 0.5, 1.0, 3.0], id: \.self) { val in
                            Button("\(val, specifier: "%.1f")%") { slippage = val }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(slippage == val ? Color.purple.opacity(0.3) : Color.white.opacity(0.07))
                                .foregroundColor(slippage == val ? .purple : .gray)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .font(.subheadline.bold())
                        }
                    }

                    Slider(value: $slippage, in: 0.1...5.0, step: 0.1)
                        .tint(.purple)

                    Text("\(slippage, specifier: "%.1f")% slippage tolerance")
                        .foregroundColor(.gray)

                    if slippage > 2 {
                        Text("Warning: High slippage may result in significant price impact")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
            }
            .navigationTitle("Slippage Tolerance")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Swap Confirmation

struct SwapConfirmationView: View {
    var quote: SwapAggregatorService.SwapQuote
    var wallet: Wallet
    var onSuccess: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isSwapping = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 24) {
                    VStack(spacing: 4) {
                        Text("\(quote.fromAmount, format: .number.precision(.fractionLength(4))) \(quote.fromToken.symbol)")
                            .font(.title.bold()).foregroundColor(.white)
                        Image(systemName: "arrow.down.circle.fill").font(.title2).foregroundColor(.purple)
                        Text("\(quote.toAmount, format: .number.precision(.fractionLength(4))) \(quote.toToken.symbol)")
                            .font(.title.bold()).foregroundColor(.green)
                    }

                    VStack(spacing: 12) {
                        ConfirmRow(label: "Rate", value: "1 \(quote.fromToken.symbol) ≈ \(String(format: "%.4f", Double(truncating: quote.exchangeRate as NSDecimalNumber))) \(quote.toToken.symbol)")
                        ConfirmRow(label: "Slippage", value: "\(quote.slippageTolerance, specifier: "%.1f")%")
                        ConfirmRow(label: "Network Fee", value: "~$\(quote.estimatedGasUSD, format: .number.precision(.fractionLength(2)))")
                        ConfirmRow(label: "Protocol Fee", value: "\(quote.protocolFeePercent, specifier: "%.2f")%")
                        ConfirmRow(label: "Router", value: quote.aggregator.rawValue)
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    if let error { Text(error).font(.caption).foregroundColor(.red) }

                    Button(action: executeSwap) {
                        if isSwapping {
                            ProgressView().tint(.white)
                        } else {
                            Label("Confirm Swap", systemImage: "arrow.2.squarepath")
                                .font(.headline).foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .disabled(isSwapping)

                    Button("Cancel") { dismiss() }.foregroundColor(.gray)
                }
                .padding()
            }
            .navigationBarHidden(true)
        }
        .preferredColorScheme(.dark)
    }

    private func executeSwap() {
        isSwapping = true
        Task {
            do {
                let hash = try await SwapAggregatorService.shared.executeSwap(quote: quote, wallet: wallet, password: "")
                await MainActor.run {
                    isSwapping = false
                    onSuccess(hash)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isSwapping = false
                }
            }
        }
    }
}
