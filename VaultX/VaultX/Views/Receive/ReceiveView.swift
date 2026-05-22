import SwiftUI
import CoreImage.CIFilterBuiltins

struct ReceiveView: View {
    var wallet: Wallet?
    @EnvironmentObject var walletManager: WalletManager
    @State private var selectedWallet: Wallet?
    @State private var showingShare = false
    @State private var copiedAddress = false

    private var activeWallet: Wallet? { selectedWallet ?? wallet ?? walletManager.wallets.first }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 28) {
                    if let w = activeWallet {
                        // Wallet selector
                        if wallet == nil {
                            Menu {
                                ForEach(walletManager.wallets) { w in
                                    Button(w.name) { selectedWallet = w }
                                }
                            } label: {
                                HStack {
                                    Text(w.name)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.gray)
                                }
                            }
                        }

                        // QR Code
                        qrCodeView(for: w.address)

                        // Address
                        VStack(spacing: 10) {
                            Text(w.chain.displayName)
                                .font(.caption)
                                .foregroundColor(.gray)

                            Text(w.address)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)

                            if let scriptType = w.bitcoinScriptType {
                                Text(scriptType.displayName)
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.orange.opacity(0.15))
                                    .foregroundColor(.orange)
                                    .clipShape(Capsule())
                            }
                        }

                        // Action buttons
                        HStack(spacing: 16) {
                            Button {
                                UIPasteboard.general.string = w.address
                                withAnimation { copiedAddress = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation { copiedAddress = false }
                                }
                            } label: {
                                Label(copiedAddress ? "Copied!" : "Copy Address",
                                      systemImage: copiedAddress ? "checkmark" : "doc.on.doc")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity, minHeight: 48)
                                    .background(copiedAddress ? Color.green.opacity(0.3) : Color.white.opacity(0.07))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            Button {
                                let av = UIActivityViewController(activityItems: [w.address], applicationActivities: nil)
                                UIApplication.shared.connectedScenes
                                    .compactMap { $0 as? UIWindowScene }
                                    .first?.windows.first?
                                    .rootViewController?.present(av, animated: true)
                            } label: {
                                Label("Share", systemImage: "square.and.arrow.up")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity, minHeight: 48)
                                    .background(Color.white.opacity(0.07))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding(.horizontal)

                        // Warning
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                            Text("Only send \(w.chain.nativeCurrency) and \(w.chain.displayName) tokens to this address")
                                .font(.caption)
                                .foregroundColor(.yellow.opacity(0.8))
                        }
                        .padding(.horizontal)
                    }
                }
                .padding()
            }
            .navigationTitle("Receive")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }

    private func qrCodeView(for address: String) -> some View {
        let qrImage = generateQRCode(from: address)
        return ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .frame(width: 220, height: 220)
            if let image = qrImage {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 190, height: 190)
            }
        }
        .shadow(color: .purple.opacity(0.3), radius: 20)
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }
        let scaleX = 200 / outputImage.extent.size.width
        let scaleY = 200 / outputImage.extent.size.height
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
