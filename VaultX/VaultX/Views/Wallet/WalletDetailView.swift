import SwiftUI

struct WalletDetailView: View {
    var wallet: Wallet
    @EnvironmentObject var walletManager: WalletManager
    @State private var transactions: [Transaction] = []
    @State private var showingSend = false
    @State private var showingReceive = false
    @State private var showingPhishingCheck = false
    @State private var urlToCheck = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    balanceHeader
                    actionButtons
                    if wallet.walletType == .multisig {
                        multiSigSection
                    }
                    transactionList
                }
                .padding()
            }
        }
        .navigationTitle(wallet.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingSend) { SendView(sourceWallet: wallet) }
        .sheet(isPresented: $showingReceive) { ReceiveView(wallet: wallet) }
        .task { await loadTransactions() }
    }

    private var balanceHeader: some View {
        VStack(spacing: 12) {
            if let balance = wallet.balance {
                Text("$\(balance.usdValue, format: .number.precision(.fractionLength(2)))")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("\(balance.nativeAmount, format: .number.precision(.fractionLength(6))) \(balance.nativeSymbol)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            HStack(spacing: 8) {
                Image(systemName: "doc.on.doc")
                    .font(.caption)
                Text(wallet.address)
                    .font(.caption)
                    .monospaced()
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .foregroundColor(.gray)
            .onTapGesture {
                UIPasteboard.general.string = wallet.address
            }

            if let scriptType = wallet.bitcoinScriptType {
                Text(scriptType.displayName)
                    .font(.caption2.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.15))
                    .foregroundColor(.orange)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var actionButtons: some View {
        HStack(spacing: 16) {
            WalletActionButton(title: "Send", icon: "paperplane.fill", color: .purple) {
                showingSend = true
            }
            WalletActionButton(title: "Receive", icon: "qrcode", color: .blue) {
                showingReceive = true
            }
            if wallet.chain.isEVM {
                WalletActionButton(title: "Swap", icon: "arrow.2.squarepath", color: .green) {}
            }
            WalletActionButton(title: "Scan URL", icon: "shield.lefthalf.filled", color: .orange) {
                showingPhishingCheck = true
            }
        }
    }

    private var multiSigSection: some View {
        Group {
            if let config = wallet.multiSigConfig {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(.purple)
                        Text("Multi-Sig: \(config.threshold)")
                            .font(.headline)
                            .foregroundColor(.white)
                    }

                    // Pending transactions
                    if !config.pendingTransactions.isEmpty {
                        ForEach(config.pendingTransactions) { tx in
                            PendingMultiSigTxRow(tx: tx, wallet: wallet)
                        }
                    }

                    ForEach(config.signers) { signer in
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.purple)
                            VStack(alignment: .leading) {
                                Text(signer.label ?? "Signer \(signer.signerIndex + 1)")
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                                Text(signer.walletAddress.map { String($0.prefix(8)) + "..." } ?? "External")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                .padding()
                .background(Color.purple.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private var transactionList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transaction History")
                .font(.headline)
                .foregroundColor(.white)

            if transactions.isEmpty {
                Text("No transactions yet")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(transactions) { tx in
                    TransactionRow(transaction: tx)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func loadTransactions() async {
        transactions = (try? await NetworkService.shared.fetchTransactions(wallet: wallet)) ?? []
    }
}

struct WalletActionButton: View {
    var title: String
    var icon: String
    var color: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 52, height: 52)
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(color)
                }
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct TransactionRow: View {
    var transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(transaction.isSend ? Color.red.opacity(0.15) : Color.green.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: transaction.isSend ? "arrow.up.right" : "arrow.down.left")
                    .foregroundColor(transaction.isSend ? .red : .green)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.type.rawValue.capitalized)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Text(transaction.timestamp, format: .relative(presentation: .named))
                    .font(.caption)
                    .foregroundColor(.gray)

                if transaction.isSuspicious {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                        Text("Suspicious")
                            .font(.caption2)
                    }
                    .foregroundColor(.orange)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(transaction.isSend ? "-" : "+")\(transaction.amount, format: .number.precision(.fractionLength(4))) \(transaction.symbol)")
                    .font(.subheadline.bold())
                    .foregroundColor(transaction.isSend ? .red : .green)

                if let usd = transaction.usdValueAtTime {
                    Text("$\(usd, format: .number.precision(.fractionLength(2)))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                statusBadge
            }
        }
    }

    private var statusBadge: some View {
        let color: Color = switch transaction.status {
        case .confirmed: .green
        case .pending: .yellow
        case .failed: .red
        case .dropped: .gray
        }
        return Text(transaction.status.rawValue.capitalized)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}

struct PendingMultiSigTxRow: View {
    var tx: PendingMultiSigTx
    var wallet: Wallet

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Pending: \(tx.amount) \(tx.symbol)")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Spacer()
                Text(tx.signatureCount)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(tx.isReady ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                    .foregroundColor(tx.isReady ? .green : .orange)
                    .clipShape(Capsule())
            }
            Text("To: \(tx.toAddress.prefix(8))...\(tx.toAddress.suffix(4))")
                .font(.caption)
                .foregroundColor(.gray)

            if tx.isReady {
                Button("Broadcast Transaction") {}
                    .font(.caption.bold())
                    .foregroundColor(.green)
            } else {
                Button("Sign Transaction") {}
                    .font(.caption.bold())
                    .foregroundColor(.purple)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
