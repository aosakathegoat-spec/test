import SwiftUI

struct AddWalletView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var walletManager: WalletManager
    @State private var selectedOption: WalletOption?

    enum WalletOption: CaseIterable, Identifiable {
        case create, importMnemonic, importPrivateKey, watchOnly, hardwareWallet

        var id: Self { self }
        var title: String {
            switch self {
            case .create: return "Create New Wallet"
            case .importMnemonic: return "Import from Seed Phrase"
            case .importPrivateKey: return "Import Private Key"
            case .watchOnly: return "Add Watch-Only Wallet"
            case .hardwareWallet: return "Connect Hardware Wallet"
            }
        }
        var icon: String {
            switch self {
            case .create: return "plus.circle.fill"
            case .importMnemonic: return "doc.text.fill"
            case .importPrivateKey: return "key.fill"
            case .watchOnly: return "eye.fill"
            case .hardwareWallet: return "externaldrive.fill"
            }
        }
        var color: Color {
            switch self {
            case .create: return .purple
            case .importMnemonic: return .blue
            case .importPrivateKey: return .orange
            case .watchOnly: return .gray
            case .hardwareWallet: return .green
            }
        }
        var description: String {
            switch self {
            case .create: return "Generate a new 24-word recovery phrase"
            case .importMnemonic: return "Restore from 12 or 24-word phrase"
            case .importPrivateKey: return "Import using a hex private key"
            case .watchOnly: return "Monitor any address without importing keys"
            case .hardwareWallet: return "Ledger or Trezor via USB/Bluetooth"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(WalletOption.allCases) { option in
                            NavigationLink(destination: destination(for: option)) {
                                WalletOptionCard(option: option)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Add Wallet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func destination(for option: WalletOption) -> some View {
        switch option {
        case .create: CreateWalletView()
        case .importMnemonic: ImportMnemonicView()
        case .importPrivateKey: ImportPrivateKeyView()
        case .watchOnly: AddWatchOnlyView()
        case .hardwareWallet: HardwareWalletView()
        }
    }
}

struct WalletOptionCard: View {
    var option: AddWalletView.WalletOption

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(option.color.opacity(0.15))
                    .frame(width: 52, height: 52)
                Image(systemName: option.icon)
                    .font(.title3)
                    .foregroundColor(option.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(option.title)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Text(option.description)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Create Wallet

struct CreateWalletView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var walletManager: WalletManager
    @State private var walletName = "My Wallet"
    @State private var selectedChains: Set<Chain> = [.ethereum, .bitcoin, .solana]
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var wordCount: MnemonicWordCount = .twentyFour
    @State private var isCreating = false
    @State private var createdMnemonic: String?
    @State private var showingMnemonic = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Name
                    FormSection(title: "Wallet Name") {
                        SecureTextField(icon: "pencil", placeholder: "e.g. Main Wallet", text: $walletName, isSecure: false)
                    }

                    // Recovery phrase length
                    FormSection(title: "Recovery Phrase Length") {
                        HStack(spacing: 12) {
                            ForEach([MnemonicWordCount.twelve, .twentyFour], id: \.rawValue) { count in
                                Button("\(count.rawValue) Words") {
                                    wordCount = count
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(wordCount == count ? Color.purple : Color.white.opacity(0.07))
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }

                    // Chain selection
                    FormSection(title: "Supported Chains") {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(Chain.allCases) { chain in
                                ChainToggle(chain: chain, isSelected: selectedChains.contains(chain)) {
                                    if selectedChains.contains(chain) {
                                        selectedChains.remove(chain)
                                    } else {
                                        selectedChains.insert(chain)
                                    }
                                }
                            }
                        }
                    }

                    // Password
                    FormSection(title: "Encryption Password") {
                        VStack(spacing: 10) {
                            SecureTextField(icon: "lock.fill", placeholder: "Password (min 12 chars)", text: $password, isSecure: true)
                            PasswordStrengthView(password: password)
                            SecureTextField(icon: "lock.fill", placeholder: "Confirm Password", text: $confirmPassword, isSecure: true)
                        }
                    }

                    // Warning
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                        Text("VaultX cannot recover your wallet if you lose your recovery phrase and password. Store both securely.")
                            .font(.caption)
                            .foregroundColor(.yellow.opacity(0.8))
                    }
                    .padding()
                    .background(Color.yellow.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button(action: createWallet) {
                        if isCreating {
                            ProgressView().tint(.white)
                        } else {
                            Text("Create Wallet")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .disabled(isCreating || !isValid)
                    .opacity(isValid ? 1 : 0.5)
                }
                .padding()
            }
        }
        .navigationTitle("Create Wallet")
        .sheet(isPresented: $showingMnemonic) {
            if let mnemonic = createdMnemonic {
                MnemonicDisplayView(mnemonic: mnemonic) { dismiss() }
            }
        }
    }

    private var isValid: Bool {
        !walletName.isEmpty
        && !selectedChains.isEmpty
        && password.count >= 12
        && password == confirmPassword
        && PasswordStrengthCalculator.score(password) >= 3
    }

    private func createWallet() {
        isCreating = true
        Task {
            do {
                let (_, mnemonic) = try await walletManager.createHDWallet(
                    name: walletName,
                    chains: Array(selectedChains),
                    password: password,
                    wordCount: wordCount
                )
                await MainActor.run {
                    createdMnemonic = mnemonic
                    isCreating = false
                    showingMnemonic = true
                }
            } catch {
                await MainActor.run { isCreating = false }
            }
        }
    }
}

// MARK: - Import Mnemonic

struct ImportMnemonicView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var walletManager: WalletManager
    @State private var mnemonic = ""
    @State private var walletName = "Imported Wallet"
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var selectedChains: Set<Chain> = [.ethereum, .bitcoin, .solana]
    @State private var isImporting = false
    @State private var isValid: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    FormSection(title: "Recovery Phrase") {
                        ZStack(alignment: .topLeading) {
                            if mnemonic.isEmpty {
                                Text("Enter 12 or 24 words separated by spaces...")
                                    .foregroundColor(.gray)
                                    .padding(12)
                            }
                            TextEditor(text: $mnemonic)
                                .foregroundColor(.white)
                                .frame(height: 120)
                                .padding(8)
                                .scrollContentBackground(.hidden)
                                .onChange(of: mnemonic) { newValue in
                                    isValid = HDWalletService().validateMnemonic(newValue.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))
                                }
                        }
                        .background(Color.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        if !mnemonic.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                                Text(isValid ? "Valid recovery phrase" : "Invalid phrase — check word count and spelling")
                                    .font(.caption)
                            }
                            .foregroundColor(isValid ? .green : .red)
                        }
                    }

                    FormSection(title: "Wallet Name") {
                        SecureTextField(icon: "pencil", placeholder: "Name", text: $walletName, isSecure: false)
                    }

                    FormSection(title: "Chains to Import") {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(Chain.allCases) { chain in
                                ChainToggle(chain: chain, isSelected: selectedChains.contains(chain)) {
                                    if selectedChains.contains(chain) {
                                        selectedChains.remove(chain)
                                    } else {
                                        selectedChains.insert(chain)
                                    }
                                }
                            }
                        }
                    }

                    FormSection(title: "Encryption Password") {
                        VStack(spacing: 10) {
                            SecureTextField(icon: "lock.fill", placeholder: "Create encryption password", text: $password, isSecure: true)
                            SecureTextField(icon: "lock.fill", placeholder: "Confirm password", text: $confirmPassword, isSecure: true)
                        }
                    }

                    if let error = errorMessage {
                        Text(error).font(.caption).foregroundColor(.red)
                    }

                    Button(action: importWallet) {
                        Group {
                            if isImporting {
                                ProgressView().tint(.white)
                            } else {
                                Text("Import Wallet").font(.headline).foregroundColor(.white)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .disabled(isImporting || !isValid || password != confirmPassword || password.count < 8)
                }
                .padding()
            }
        }
        .navigationTitle("Import Seed Phrase")
    }

    private func importWallet() {
        isImporting = true
        errorMessage = nil
        Task {
            do {
                let _ = try await walletManager.importFromMnemonic(
                    name: walletName,
                    mnemonic: mnemonic.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
                    chains: Array(selectedChains),
                    password: password
                )
                await MainActor.run {
                    isImporting = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isImporting = false
                }
            }
        }
    }
}

// MARK: - Mnemonic Display (backup confirmation)

struct MnemonicDisplayView: View {
    var mnemonic: String
    var onDone: () -> Void

    @State private var confirmed = false
    @State private var currentStep = 0
    @State private var verificationIndices: [Int] = []
    @State private var verificationAnswers: [String] = []

    private var words: [String] { mnemonic.components(separatedBy: " ") }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 24) {
                    if currentStep == 0 {
                        seedPhraseDisplay
                    } else {
                        seedPhraseVerification
                    }
                }
                .padding()
            }
            .navigationTitle(currentStep == 0 ? "Your Recovery Phrase" : "Verify Phrase")
        }
        .preferredColorScheme(.dark)
    }

    private var seedPhraseDisplay: some View {
        VStack(spacing: 20) {
            // Security warning
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.yellow)
                Text("Write these 24 words down in order and store them somewhere safe.")
                    .font(.subheadline)
                    .foregroundColor(.yellow)
                    .multilineTextAlignment(.center)
                Text("Never share your recovery phrase with anyone. VaultX will never ask for it.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(Color.yellow.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // Word grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                ForEach(Array(words.enumerated()), id: \.offset) { idx, word in
                    HStack(spacing: 6) {
                        Text("\(idx + 1).")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .frame(width: 22, alignment: .trailing)
                        Text(word)
                            .font(.caption.bold())
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            Button("I've Written It Down") {
                currentStep = 1
                // Pick 3 random words to verify
                verificationIndices = Array((0..<words.count).shuffled().prefix(3)).sorted()
                verificationAnswers = Array(repeating: "", count: 3)
            }
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Color.purple)
            .foregroundColor(.white)
            .font(.headline)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private var seedPhraseVerification: some View {
        VStack(spacing: 24) {
            Text("Verify Recovery Phrase")
                .font(.title3.bold())
                .foregroundColor(.white)
            Text("Enter the words at the positions below to confirm you've saved your phrase.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)

            ForEach(Array(verificationIndices.enumerated()), id: \.offset) { i, wordIdx in
                HStack {
                    Text("Word #\(wordIdx + 1)")
                        .foregroundColor(.gray)
                        .frame(width: 90, alignment: .leading)
                    SecureTextField(icon: "textformat", placeholder: "Enter word", text: $verificationAnswers[i], isSecure: false)
                }
            }

            Button("Confirm") {
                let allCorrect = zip(verificationIndices, verificationAnswers).allSatisfy { (idx, answer) in
                    answer.lowercased().trimmingCharacters(in: .whitespaces) == words[idx]
                }
                if allCorrect { onDone() }
            }
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Color.green)
            .foregroundColor(.white)
            .font(.headline)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

// MARK: - Stubs for other wallet types

struct ImportPrivateKeyView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Text("Import Private Key")
                .foregroundColor(.white)
        }
        .navigationTitle("Import Private Key")
    }
}

struct AddWatchOnlyView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Text("Watch Only").foregroundColor(.white)
        }
        .navigationTitle("Watch-Only Wallet")
    }
}

struct HardwareWalletView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "externaldrive.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                Text("Hardware Wallet")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                Text("Connect your Ledger or Trezor via USB or Bluetooth")
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
        .navigationTitle("Hardware Wallet")
    }
}

// MARK: - Form Helpers

struct FormSection<Content: View>: View {
    var title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(.gray)
            content()
        }
    }
}

struct ChainToggle: View {
    var chain: Chain
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: chain.symbolImage)
                    .font(.caption)
                Text(chain.displayName)
                    .font(.caption.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? Color.purple.opacity(0.3) : Color.white.opacity(0.05))
            .foregroundColor(isSelected ? .purple : .gray)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.purple : Color.clear, lineWidth: 1)
            )
        }
    }
}
