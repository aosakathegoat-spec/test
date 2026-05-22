import SwiftUI

struct WalletListView: View {
    @EnvironmentObject var walletManager: WalletManager
    @State private var showingAddWallet = false
    @State private var showingMultiSig = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if walletManager.wallets.isEmpty {
                    EmptyWalletsView(showingAddWallet: $showingAddWallet)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(Chain.allCases) { chain in
                                let chainWallets = walletManager.wallets.filter { $0.chain == chain && !$0.isArchived }
                                if !chainWallets.isEmpty {
                                    WalletChainSection(chain: chain, wallets: chainWallets)
                                }
                            }

                            // Multi-sig section
                            let multiSigWallets = walletManager.wallets.filter { $0.walletType == .multisig }
                            if !multiSigWallets.isEmpty {
                                MultiSigWalletSection(wallets: multiSigWallets)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Wallets")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        showingMultiSig = true
                    } label: {
                        Image(systemName: "person.2.fill")
                    }

                    Button {
                        showingAddWallet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.purple)
                    }
                }
            }
            .sheet(isPresented: $showingAddWallet) { AddWalletView() }
            .sheet(isPresented: $showingMultiSig) { CreateMultiSigView() }
        }
    }
}

// MARK: - Chain Section

struct WalletChainSection: View {
    var chain: Chain
    var wallets: [Wallet]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: chain.symbolImage)
                    .foregroundColor(.purple)
                Text(chain.displayName)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 4)

            ForEach(wallets) { wallet in
                NavigationLink(destination: WalletDetailView(wallet: wallet)) {
                    WalletCard(wallet: wallet)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Wallet Card

struct WalletCard: View {
    var wallet: Wallet

    var body: some View {
        HStack(spacing: 14) {
            walletIcon

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(wallet.name)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)

                    if wallet.walletType == .watchOnly {
                        WalletTypeBadge(label: "Watch", color: .orange)
                    } else if wallet.walletType == .hardware {
                        WalletTypeBadge(label: "HW", color: .blue)
                    } else if wallet.walletType == .multisig {
                        WalletTypeBadge(label: wallet.multiSigConfig?.threshold ?? "Multi-sig", color: .purple)
                    }
                }

                Text(wallet.shortAddress)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .monospaced()

                if let scriptType = wallet.bitcoinScriptType {
                    Text(scriptType.displayName)
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let balance = wallet.balance {
                    Text("$\(balance.usdValue, format: .number.precision(.fractionLength(2)))")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Text("\(balance.nativeAmount, format: .number.precision(.fractionLength(4))) \(balance.nativeSymbol)")
                        .font(.caption)
                        .foregroundColor(.gray)
                } else {
                    ProgressView()
                        .tint(.gray)
                        .scaleEffect(0.8)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(wallet.isPrimary ? Color.purple.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
    }

    private var walletIcon: some View {
        ZStack {
            Circle()
                .fill(Color.purple.opacity(0.15))
                .frame(width: 44, height: 44)
            Image(systemName: wallet.chain.symbolImage)
                .font(.title3)
                .foregroundColor(.purple)
        }
    }
}

struct WalletTypeBadge: View {
    var label: String
    var color: Color

    var body: some View {
        Text(label)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}

// MARK: - Multi-Sig Section

struct MultiSigWalletSection: View {
    var wallets: [Wallet]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.purple)
                Text("Multi-Signature")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 4)

            ForEach(wallets) { wallet in
                NavigationLink(destination: WalletDetailView(wallet: wallet)) {
                    WalletCard(wallet: wallet)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Empty State

struct EmptyWalletsView: View {
    @Binding var showingAddWallet: Bool

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "wallet.pass.fill")
                .font(.system(size: 70))
                .foregroundColor(.purple.opacity(0.5))

            VStack(spacing: 8) {
                Text("No Wallets Yet")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                Text("Create a new wallet or import an existing one using your seed phrase or private key")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button("Add Your First Wallet") {
                showingAddWallet = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
        }
    }
}
