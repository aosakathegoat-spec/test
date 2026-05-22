import SwiftUI

struct SendView: View {
    var sourceWallet: Wallet?
    @EnvironmentObject var walletManager: WalletManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedWallet: Wallet?
    @State private var recipientAddress = ""
    @State private var amount = ""
    @State private var memo = ""
    @State private var gasEstimate: GasEstimate?
    @State private var phishingResult: PhishingDetectionService.TransactionRiskResult?
    @State private var showingConfirmation = false
    @State private var isLoading = false
    @State private var isBroadcasting = false
    @State private var txHash: String?
    @State private var showingQRScanner = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        walletSelector
                        recipientField
                        amountField
                        if let estimate = gasEstimate {
                            feeCard(estimate: estimate)
                        }
                        if let risk = phishingResult {
                            riskCard(risk: risk)
                        }
                        sendButton
                    }
                    .padding()
                }
            }
            .navigationTitle("Send")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingConfirmation) {
                if let wallet = selectedWallet ?? sourceWallet {
                    SendConfirmationView(
                        wallet: wallet,
                        recipient: recipientAddress,
                        amount: Decimal(string: amount) ?? 0,
                        gasEstimate: gasEstimate
                    ) { hash in
                        txHash = hash
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: recipientAddress) { _ in analyzeRecipient() }
        .onChange(of: amount) { _ in estimateGas() }
    }

    private var walletSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("From")
                .font(.subheadline.bold())
                .foregroundColor(.gray)

            Menu {
                ForEach(walletManager.wallets.filter { $0.walletType != .watchOnly }) { wallet in
                    Button(action: { selectedWallet = wallet }) {
                        Label(wallet.name, systemImage: wallet.chain.symbolImage)
                    }
                }
            } label: {
                HStack {
                    let wallet = selectedWallet ?? sourceWallet ?? walletManager.wallets.first
                    if let w = wallet {
                        Image(systemName: w.chain.symbolImage)
                            .foregroundColor(.purple)
                        VStack(alignment: .leading) {
                            Text(w.name)
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            if let balance = w.balance {
                                Text("\(balance.nativeAmount, format: .number.precision(.fractionLength(4))) \(balance.nativeSymbol)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    } else {
                        Text("Select wallet")
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var recipientField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("To")
                .font(.subheadline.bold())
                .foregroundColor(.gray)

            HStack {
                Image(systemName: "person.fill")
                    .foregroundColor(.gray)
                TextField("Address or ENS", text: $recipientAddress)
                    .foregroundColor(.white)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Spacer()
                Button {
                    recipientAddress = UIPasteboard.general.string ?? ""
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .foregroundColor(.purple)
                }
                Button {
                    showingQRScanner = true
                } label: {
                    Image(systemName: "qrcode.viewfinder")
                        .foregroundColor(.purple)
                }
            }
            .padding()
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var amountField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Amount")
                .font(.subheadline.bold())
                .foregroundColor(.gray)

            HStack {
                TextField("0.0", text: $amount)
                    .keyboardType(.decimalPad)
                    .foregroundColor(.white)
                    .font(.title2.bold())

                let symbol = (selectedWallet ?? sourceWallet)?.chain.nativeCurrency ?? ""
                Text(symbol)
                    .foregroundColor(.gray)
                    .font(.subheadline)

                Button("MAX") {
                    if let balance = (selectedWallet ?? sourceWallet)?.balance {
                        amount = "\(balance.nativeAmount)"
                    }
                }
                .font(.caption.bold())
                .foregroundColor(.purple)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.purple.opacity(0.15))
                .clipShape(Capsule())
            }
            .padding()
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func feeCard(estimate: GasEstimate) -> some View {
        HStack {
            Image(systemName: "fuelpump.fill")
                .foregroundColor(.orange)
            Text("Network Fee")
                .font(.subheadline)
                .foregroundColor(.gray)
            Spacer()
            VStack(alignment: .trailing) {
                Text("$\(estimate.estimatedFeeUSD, format: .number.precision(.fractionLength(4)))")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Text("\(estimate.gasPriceGwei) Gwei")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func riskCard(risk: PhishingDetectionService.TransactionRiskResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: risk.riskScore >= 50 ? "exclamationmark.triangle.fill" : "checkmark.shield.fill")
                    .foregroundColor(risk.riskScore >= 50 ? .red : risk.riskScore >= 20 ? .orange : .green)
                Text(risk.riskScore >= 50 ? "High Risk Transaction" : risk.riskScore >= 20 ? "Caution Required" : "Transaction Looks Safe")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
            }
            ForEach(risk.flags, id: \.self) { flag in
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "dot.circle.fill").font(.caption)
                    Text(flag).font(.caption)
                }
                .foregroundColor(.orange)
            }
        }
        .padding()
        .background(risk.riskScore >= 50 ? Color.red.opacity(0.1) : Color.orange.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(risk.riskScore >= 50 ? Color.red.opacity(0.3) : Color.orange.opacity(0.2), lineWidth: 1)
        )
    }

    private var sendButton: some View {
        Button(action: { showingConfirmation = true }) {
            Label("Review Transaction", systemImage: "arrow.right.circle.fill")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(
                    LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(recipientAddress.isEmpty || amount.isEmpty || Double(amount) == nil)
        .opacity(recipientAddress.isEmpty || amount.isEmpty ? 0.5 : 1)
    }

    private func analyzeRecipient() {
        guard !recipientAddress.isEmpty else { phishingResult = nil; return }
        let wallet = selectedWallet ?? sourceWallet
        let amountDecimal = Decimal(string: amount) ?? 0
        phishingResult = PhishingDetectionService.shared.scoreTransaction(
            toAddress: recipientAddress,
            amount: amountDecimal,
            amountUSD: 0,
            chain: wallet?.chain ?? .ethereum,
            inputData: nil
        )
    }

    private func estimateGas() {
        guard let wallet = selectedWallet ?? sourceWallet, wallet.chain.isEVM, !recipientAddress.isEmpty else { return }
        Task {
            gasEstimate = try? await NetworkService.shared.estimateGas(
                chain: wallet.chain,
                from: wallet.address,
                to: recipientAddress,
                data: nil
            )
        }
    }
}

// MARK: - Confirmation Sheet

struct SendConfirmationView: View {
    var wallet: Wallet
    var recipient: String
    var amount: Decimal
    var gasEstimate: GasEstimate?
    var onSuccess: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isBroadcasting = false
    @State private var biometricError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 24) {
                    Image(systemName: "paperplane.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.purple)

                    VStack(spacing: 6) {
                        Text("Confirm Transaction")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                        Text("Authenticate with \(BiometricAuthService().biometryName) to sign and send")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 12) {
                        ConfirmRow(label: "From", value: wallet.shortAddress)
                        ConfirmRow(label: "To", value: "\(recipient.prefix(6))...\(recipient.suffix(4))")
                        ConfirmRow(label: "Amount", value: "\(amount) \(wallet.chain.nativeCurrency)")
                        if let fee = gasEstimate {
                            ConfirmRow(label: "Network Fee", value: "~$\(fee.estimatedFeeUSD, format: .number.precision(.fractionLength(4)))")
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    if let error = biometricError {
                        Text(error).font(.caption).foregroundColor(.red)
                    }

                    Button(action: sendTransaction) {
                        if isBroadcasting {
                            ProgressView().tint(.white)
                        } else {
                            Label("Authenticate & Send", systemImage: BiometricAuthService().isFaceIDAvailable ? "faceid" : "touchid")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .disabled(isBroadcasting)

                    Button("Cancel") { dismiss() }
                        .foregroundColor(.gray)
                }
                .padding()
            }
            .navigationBarHidden(true)
        }
        .preferredColorScheme(.dark)
    }

    private func sendTransaction() {
        isBroadcasting = true
        biometricError = nil

        Task {
            let bio = BiometricAuthService()
            let result = await bio.authenticate(reason: "Authorize sending \(amount) \(wallet.chain.nativeCurrency)")

            guard result.success else {
                await MainActor.run {
                    biometricError = result.error?.errorDescription ?? "Authentication failed"
                    isBroadcasting = false
                }
                return
            }

            // In production: sign tx with private key, broadcast
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            let mockHash = "0x" + UUID().uuidString.replacingOccurrences(of: "-", with: "")

            await MainActor.run {
                isBroadcasting = false
                onSuccess(mockHash)
                dismiss()
            }
        }
    }
}

struct ConfirmRow: View {
    var label: String
    var value: String

    var body: some View {
        HStack {
            Text(label).foregroundColor(.gray)
            Spacer()
            Text(value).foregroundColor(.white).bold()
        }
        .font(.subheadline)
    }
}
