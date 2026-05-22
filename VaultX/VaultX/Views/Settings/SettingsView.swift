import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var securityManager: SecurityManager
    @State private var showing2FASetup = false
    @State private var showingBackup = false
    @State private var showingSecurityCenter = false
    @State private var showingPrivacy = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                List {
                    securitySection
                    walletSection
                    taxSection
                    notificationsSection
                    aboutSection
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showing2FASetup) { TwoFactorSetupView() }
            .sheet(isPresented: $showingBackup) { BackupView() }
            .sheet(isPresented: $showingSecurityCenter) { SecurityCenterView() }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Security Section

    private var securitySection: some View {
        Section {
            // Security Score card
            Button { showingSecurityCenter = true } label: {
                HStack {
                    ZStack {
                        Circle()
                            .stroke(
                                securityManager.securityScore >= 80 ? Color.green : securityManager.securityScore >= 50 ? Color.yellow : Color.red,
                                lineWidth: 3
                            )
                            .frame(width: 44, height: 44)
                        Text("\(securityManager.securityScore)")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Security Score")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                        Text(securityManager.securityScore >= 80 ? "Excellent" : securityManager.securityScore >= 50 ? "Fair" : "Needs Attention")
                            .font(.caption)
                            .foregroundColor(securityManager.securityScore >= 80 ? .green : securityManager.securityScore >= 50 ? .yellow : .red)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundColor(.gray)
                }
            }
            .listRowBackground(Color.white.opacity(0.05))

            // 2FA — Top differentiator vs Phantom
            Button { showing2FASetup = true } label: {
                SettingsRow(
                    icon: "lock.shield.fill",
                    iconColor: .purple,
                    title: "Two-Factor Authentication",
                    subtitle: "Not enabled — tap to set up",
                    badge: "Recommended",
                    badgeColor: .orange
                )
            }
            .listRowBackground(Color.white.opacity(0.05))

            NavigationLink {
                BiometricSettingsView()
            } label: {
                SettingsRow(
                    icon: "faceid",
                    iconColor: .blue,
                    title: "Face ID / Touch ID",
                    subtitle: "Unlock and authorize transactions"
                )
            }
            .listRowBackground(Color.white.opacity(0.05))

            NavigationLink {
                TrustedDevicesView()
            } label: {
                SettingsRow(
                    icon: "iphone.badge.play",
                    iconColor: .green,
                    title: "Trusted Devices",
                    subtitle: "Manage devices with wallet access"
                )
            }
            .listRowBackground(Color.white.opacity(0.05))

        } header: {
            Text("Security")
                .foregroundColor(.gray)
        }
    }

    // MARK: - Wallet Section

    private var walletSection: some View {
        Section {
            Button { showingBackup = true } label: {
                SettingsRow(
                    icon: "icloud.and.arrow.up.fill",
                    iconColor: .blue,
                    title: "Encrypted Backup",
                    subtitle: "Backup all wallets to iCloud",
                    badge: "Not backed up",
                    badgeColor: .red
                )
            }
            .listRowBackground(Color.white.opacity(0.05))

            NavigationLink {
                CreateMultiSigView()
            } label: {
                SettingsRow(
                    icon: "person.2.fill",
                    iconColor: .purple,
                    title: "Multi-Signature Wallets",
                    subtitle: "Require multiple approvals for transactions"
                )
            }
            .listRowBackground(Color.white.opacity(0.05))

            NavigationLink {
                HardwareWalletView()
            } label: {
                SettingsRow(
                    icon: "externaldrive.fill",
                    iconColor: .green,
                    title: "Hardware Wallets",
                    subtitle: "Connect Ledger or Trezor"
                )
            }
            .listRowBackground(Color.white.opacity(0.05))

        } header: {
            Text("Wallet")
                .foregroundColor(.gray)
        }
    }

    // MARK: - Tax Section

    private var taxSection: some View {
        Section {
            NavigationLink {
                TaxReportView()
            } label: {
                SettingsRow(
                    icon: "doc.text.fill",
                    iconColor: .yellow,
                    title: "Tax Reports",
                    subtitle: "FIFO, LIFO, HIFO capital gains reporting"
                )
            }
            .listRowBackground(Color.white.opacity(0.05))

            NavigationLink {
                PriceAlertsView()
            } label: {
                SettingsRow(
                    icon: "bell.badge.fill",
                    iconColor: .orange,
                    title: "Price Alerts",
                    subtitle: "Get notified at target prices"
                )
            }
            .listRowBackground(Color.white.opacity(0.05))

        } header: {
            Text("Portfolio & Tax")
                .foregroundColor(.gray)
        }
    }

    private var notificationsSection: some View {
        Section {
            NavigationLink {
                NotificationSettingsView()
            } label: {
                SettingsRow(
                    icon: "bell.fill",
                    iconColor: .red,
                    title: "Notifications",
                    subtitle: "Transactions, alerts, multi-sig requests"
                )
            }
            .listRowBackground(Color.white.opacity(0.05))
        } header: {
            Text("Notifications")
                .foregroundColor(.gray)
        }
    }

    private var aboutSection: some View {
        Section {
            Button {
                appState.signOut()
            } label: {
                SettingsRow(
                    icon: "arrow.backward.square.fill",
                    iconColor: .red,
                    title: "Sign Out",
                    subtitle: "Removes session — wallet keys remain secure"
                )
            }
            .listRowBackground(Color.white.opacity(0.05))
        } header: {
            Text("Account")
                .foregroundColor(.gray)
        }
    }
}

// MARK: - Settings Row

struct SettingsRow: View {
    var icon: String
    var iconColor: Color
    var title: String
    var subtitle: String
    var badge: String? = nil
    var badgeColor: Color = .orange

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            if let badge {
                Text(badge)
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(badgeColor.opacity(0.15))
                    .foregroundColor(badgeColor)
                    .clipShape(Capsule())
            }
        }
    }
}

// MARK: - 2FA Setup View

struct TwoFactorSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var step = 0
    @State private var secret = ""
    @State private var qrCodeURI = ""
    @State private var verificationCode = ""
    @State private var backupCodes: [String] = []
    @State private var isVerifying = false
    @State private var error: String?

    private let twoFA = TwoFactorAuthService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 24) {
                    switch step {
                    case 0: introStep
                    case 1: qrStep
                    case 2: verifyStep
                    case 3: backupCodesStep
                    default: EmptyView()
                    }
                }
                .padding()
            }
            .navigationTitle("Set Up 2FA")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { setupSecret() }
    }

    private var introStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 70))
                .foregroundColor(.purple)

            VStack(spacing: 8) {
                Text("Two-Factor Authentication")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                Text("Add an extra layer of security. A code from your authenticator app will be required at login.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                Text("Phantom Wallet has NO 2FA. VaultX protects you even if your password is compromised.")
                    .font(.caption)
                    .foregroundColor(.purple)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color.purple.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Button("Get Started") { step = 1 }
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(Color.purple)
                .foregroundColor(.white)
                .font(.headline)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private var qrStep: some View {
        VStack(spacing: 20) {
            Text("Scan this QR code in your authenticator app")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)

            // QR Code placeholder
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .frame(width: 200, height: 200)
                .overlay(
                    Text("QR Code\n(generated at runtime)")
                        .font(.caption)
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                )

            Text("Or enter manually:")
                .font(.caption)
                .foregroundColor(.gray)

            Text(secret)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundColor(.white)
                .padding()
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .onTapGesture {
                    UIPasteboard.general.string = secret
                }

            Button("I've Added It") { step = 2 }
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(Color.purple)
                .foregroundColor(.white)
                .font(.headline)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private var verifyStep: some View {
        VStack(spacing: 20) {
            Text("Enter the 6-digit code from your app to verify setup")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)

            OTPInputView(code: $verificationCode, length: 6)

            if let error { Text(error).font(.caption).foregroundColor(.red) }

            Button(action: verify) {
                if isVerifying {
                    ProgressView().tint(.white)
                } else {
                    Text("Verify & Enable 2FA")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Color.purple)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .disabled(verificationCode.count != 6 || isVerifying)
        }
    }

    private var backupCodesStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("2FA Enabled!")
                .font(.title2.bold())
                .foregroundColor(.white)

            Text("Save these backup codes somewhere safe. Each can be used once if you lose your phone.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(backupCodes, id: \.self) { code in
                    Text(code)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            Button("Done") { dismiss() }
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(Color.green)
                .foregroundColor(.white)
                .font(.headline)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func setupSecret() {
        let result = twoFA.generateSecret()
        secret = result.secret
        qrCodeURI = result.provisioningURI
    }

    private func verify() {
        isVerifying = true
        error = nil
        Task {
            let valid = twoFA.verify(code: verificationCode, secret: secret)
            await MainActor.run {
                isVerifying = false
                if valid {
                    backupCodes = twoFA.generateBackupCodes()
                    step = 3
                    // In production: save secret to Keychain
                } else {
                    error = "Incorrect code. Please try again."
                    verificationCode = ""
                }
            }
        }
    }
}

// MARK: - Stub Views

struct BackupView: View {
    var body: some View { ZStack { Color.black.ignoresSafeArea(); Text("Backup").foregroundColor(.white) } }
}
struct SecurityCenterView: View {
    var body: some View { ZStack { Color.black.ignoresSafeArea(); Text("Security Center").foregroundColor(.white) } }
}
struct BiometricSettingsView: View {
    var body: some View { ZStack { Color.black.ignoresSafeArea(); Text("Biometric Settings").foregroundColor(.white) } }
}
struct TrustedDevicesView: View {
    var body: some View { ZStack { Color.black.ignoresSafeArea(); Text("Trusted Devices").foregroundColor(.white) } }
}
struct NotificationSettingsView: View {
    var body: some View { ZStack { Color.black.ignoresSafeArea(); Text("Notifications").foregroundColor(.white) } }
}
struct CreateMultiSigView: View {
    var body: some View { ZStack { Color.black.ignoresSafeArea(); Text("Create Multi-Sig Wallet").foregroundColor(.white) } }
}
