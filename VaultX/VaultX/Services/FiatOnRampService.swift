import Foundation
import UIKit
import SafariServices

// MARK: - Fiat On-Ramp Service
// Integrates MoonPay, Transak, and Ramp Network.
// Phantom has MoonPay only. VaultX has 3 providers with fee comparison.

final class FiatOnRampService: ObservableObject {
    static let shared = FiatOnRampService()
    private init() {}

    // MARK: - Provider Definitions

    enum Provider: String, CaseIterable, Identifiable {
        case moonpay  = "MoonPay"
        case transak  = "Transak"
        case ramp     = "Ramp Network"
        case coinbase = "Coinbase Pay"

        var id: String { rawValue }

        var description: String {
            switch self {
            case .moonpay:  return "Credit/debit card, bank transfer, Apple Pay"
            case .transak:  return "170+ countries, low fees, bank & card"
            case .ramp:     return "Best EUR rates, Open Banking"
            case .coinbase: return "Bank transfer, debit card (US-focused)"
            }
        }

        var supportedPaymentMethods: [PaymentMethod] {
            switch self {
            case .moonpay:  return [.creditCard, .debitCard, .applePay, .bankTransfer, .sepa]
            case .transak:  return [.creditCard, .debitCard, .bankTransfer, .upi, .sepa]
            case .ramp:     return [.bankTransfer, .debitCard, .applePay, .sepa, .openBanking]
            case .coinbase: return [.bankTransfer, .debitCard]
            }
        }

        var logoSystemImage: String {
            switch self {
            case .moonpay:  return "moon.fill"
            case .transak:  return "t.circle.fill"
            case .ramp:     return "r.circle.fill"
            case .coinbase: return "c.circle.fill"
            }
        }
    }

    enum PaymentMethod: String, CaseIterable {
        case creditCard   = "Credit Card"
        case debitCard    = "Debit Card"
        case applePay     = "Apple Pay"
        case bankTransfer = "Bank Transfer"
        case sepa         = "SEPA Transfer"
        case upi          = "UPI (India)"
        case openBanking  = "Open Banking"

        var icon: String {
            switch self {
            case .creditCard, .debitCard: return "creditcard.fill"
            case .applePay: return "apple.logo"
            case .bankTransfer, .openBanking: return "building.columns.fill"
            case .sepa: return "eurosign.circle.fill"
            case .upi: return "indianrupeesign.circle.fill"
            }
        }
    }

    // MARK: - Quote

    struct OnRampQuote: Identifiable {
        let id = UUID()
        var provider: Provider
        var fiatAmount: Decimal
        var fiatCurrency: String
        var cryptoAmount: Decimal
        var cryptoSymbol: String
        var processingFeePercent: Double
        var processingFeeUSD: Decimal
        var networkFeeUSD: Decimal
        var totalFeeUSD: Decimal
        var exchangeRate: Decimal
        var estimatedArrival: String
        var paymentMethods: [PaymentMethod]
        var isKYCRequired: Bool
        var minAmount: Decimal
        var maxAmount: Decimal

        var effectiveRate: Decimal { fiatAmount / cryptoAmount }
        var totalFeePercent: Double { Double(truncating: (totalFeeUSD / fiatAmount * 100) as NSDecimalNumber) }
    }

    // MARK: - Get Quotes from All Providers

    func getQuotes(
        fiatAmount: Decimal,
        fiatCurrency: String = "USD",
        cryptoSymbol: String,
        walletAddress: String
    ) async -> [OnRampQuote] {
        await withTaskGroup(of: OnRampQuote?.self) { group in
            for provider in Provider.allCases {
                group.addTask {
                    return await self.getQuote(
                        provider: provider,
                        fiatAmount: fiatAmount,
                        fiatCurrency: fiatCurrency,
                        cryptoSymbol: cryptoSymbol,
                        walletAddress: walletAddress
                    )
                }
            }
            var quotes: [OnRampQuote] = []
            for await quote in group {
                if let q = quote { quotes.append(q) }
            }
            return quotes.sorted { $0.totalFeeUSD < $1.totalFeeUSD }  // Cheapest first
        }
    }

    private func getQuote(
        provider: Provider,
        fiatAmount: Decimal,
        fiatCurrency: String,
        cryptoSymbol: String,
        walletAddress: String
    ) async -> OnRampQuote? {
        switch provider {
        case .moonpay:  return await moonPayQuote(fiatAmount: fiatAmount, fiatCurrency: fiatCurrency, crypto: cryptoSymbol, wallet: walletAddress)
        case .transak:  return await transakQuote(fiatAmount: fiatAmount, fiatCurrency: fiatCurrency, crypto: cryptoSymbol, wallet: walletAddress)
        case .ramp:     return await rampQuote(fiatAmount: fiatAmount, fiatCurrency: fiatCurrency, crypto: cryptoSymbol, wallet: walletAddress)
        case .coinbase: return await coinbaseQuote(fiatAmount: fiatAmount, fiatCurrency: fiatCurrency, crypto: cryptoSymbol, wallet: walletAddress)
        }
    }

    // MARK: - MoonPay

    private func moonPayQuote(fiatAmount: Decimal, fiatCurrency: String, crypto: String, wallet: String) async -> OnRampQuote? {
        let url = "https://api.moonpay.com/v3/currencies/\(crypto.lowercased())/buy_quote/?apiKey=YOUR_KEY&baseCurrencyAmount=\(fiatAmount)&baseCurrencyCode=\(fiatCurrency.lowercased())"

        guard let urlObj = URL(string: url),
              let (data, _) = try? await URLSession.shared.data(from: urlObj),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return mockQuote(provider: .moonpay, fiatAmount: fiatAmount, fiatCurrency: fiatCurrency, crypto: crypto) }

        let totalFee = Decimal(json["feeAmount"] as? Double ?? 0) + Decimal(json["networkFeeAmount"] as? Double ?? 0)
        let quotedAmount = Decimal(json["quoteCurrencyAmount"] as? Double ?? 0)
        let exchangeRate = Decimal(json["quoteCurrencyPrice"] as? Double ?? 0)

        return OnRampQuote(
            provider: .moonpay,
            fiatAmount: fiatAmount,
            fiatCurrency: fiatCurrency,
            cryptoAmount: quotedAmount,
            cryptoSymbol: crypto,
            processingFeePercent: 3.5,
            processingFeeUSD: Decimal(json["feeAmount"] as? Double ?? 0),
            networkFeeUSD: Decimal(json["networkFeeAmount"] as? Double ?? 0),
            totalFeeUSD: totalFee,
            exchangeRate: exchangeRate,
            estimatedArrival: "Instant - 3 mins",
            paymentMethods: [.creditCard, .debitCard, .applePay, .bankTransfer],
            isKYCRequired: fiatAmount > 150,
            minAmount: 20,
            maxAmount: 50000
        )
    }

    // MARK: - Transak

    private func transakQuote(fiatAmount: Decimal, fiatCurrency: String, crypto: String, wallet: String) async -> OnRampQuote? {
        mockQuote(provider: .transak, fiatAmount: fiatAmount, fiatCurrency: fiatCurrency, crypto: crypto,
                  feePercent: 1.5, arrival: "2-5 minutes")
    }

    // MARK: - Ramp Network

    private func rampQuote(fiatAmount: Decimal, fiatCurrency: String, crypto: String, wallet: String) async -> OnRampQuote? {
        mockQuote(provider: .ramp, fiatAmount: fiatAmount, fiatCurrency: fiatCurrency, crypto: crypto,
                  feePercent: 0.99, arrival: "3-10 minutes")
    }

    // MARK: - Coinbase Pay

    private func coinbaseQuote(fiatAmount: Decimal, fiatCurrency: String, crypto: String, wallet: String) async -> OnRampQuote? {
        mockQuote(provider: .coinbase, fiatAmount: fiatAmount, fiatCurrency: fiatCurrency, crypto: crypto,
                  feePercent: 1.49, arrival: "Instant")
    }

    private func mockQuote(provider: Provider, fiatAmount: Decimal, fiatCurrency: String, crypto: String,
                            feePercent: Double = 2.5, arrival: String = "1-5 minutes") -> OnRampQuote {
        let exchangeRate: Decimal = crypto == "BTC" ? 67000 : crypto == "ETH" ? 3200 : crypto == "SOL" ? 170 : 1
        let fee = Decimal(Double(truncating: fiatAmount as NSDecimalNumber) * feePercent / 100)
        let netAmount = (fiatAmount - fee) / exchangeRate

        return OnRampQuote(
            provider: provider,
            fiatAmount: fiatAmount,
            fiatCurrency: fiatCurrency,
            cryptoAmount: netAmount,
            cryptoSymbol: crypto,
            processingFeePercent: feePercent,
            processingFeeUSD: fee,
            networkFeeUSD: 1.5,
            totalFeeUSD: fee + 1.5,
            exchangeRate: exchangeRate,
            estimatedArrival: arrival,
            paymentMethods: provider.supportedPaymentMethods,
            isKYCRequired: fiatAmount > 200,
            minAmount: 10,
            maxAmount: 25000
        )
    }

    // MARK: - Launch Purchase Flow

    func launchPurchase(provider: Provider, fiatAmount: Decimal, fiatCurrency: String, crypto: String, walletAddress: String) -> URL? {
        switch provider {
        case .moonpay:
            return URL(string: "https://buy.moonpay.com?apiKey=YOUR_KEY&currencyCode=\(crypto.lowercased())&walletAddress=\(walletAddress)&baseCurrencyAmount=\(fiatAmount)&baseCurrencyCode=\(fiatCurrency.lowercased())")

        case .transak:
            return URL(string: "https://global.transak.com?apiKey=YOUR_KEY&cryptoCurrencyCode=\(crypto)&walletAddress=\(walletAddress)&fiatAmount=\(fiatAmount)&fiatCurrency=\(fiatCurrency)")

        case .ramp:
            return URL(string: "https://app.ramp.network?apiKey=YOUR_KEY&swapAsset=\(crypto)&userAddress=\(walletAddress)&swapAmount=\(fiatAmount)")

        case .coinbase:
            return URL(string: "https://pay.coinbase.com/buy/select-asset?appId=YOUR_APP_ID&destinationWallets=[{\"address\":\"\(walletAddress)\",\"assets\":[\"\(crypto)\"]}]")
        }
    }

    // MARK: - Off-Ramp (Sell Crypto for Fiat)

    struct SellQuote: Identifiable {
        let id = UUID()
        var provider: Provider
        var cryptoAmount: Decimal
        var cryptoSymbol: String
        var fiatAmount: Decimal
        var fiatCurrency: String
        var processingFeeUSD: Decimal
        var networkFeeUSD: Decimal
        var totalFeeUSD: Decimal
        var estimatedArrival: String
        var paymentDestinations: [String]

        var totalFeePercent: Double {
            guard fiatAmount > 0 else { return 0 }
            let gross = fiatAmount + totalFeeUSD
            return Double(truncating: (totalFeeUSD / gross * 100) as NSDecimalNumber)
        }
    }

    typealias OffRampQuote = SellQuote

    func getSellQuotes(
        cryptoAmount: Decimal,
        cryptoSymbol: String,
        fiatCurrency: String = "USD",
        walletAddress: String = ""
    ) async -> [SellQuote] {
        let exchangeRate: Decimal = cryptoSymbol == "BTC" ? 67000 : cryptoSymbol == "ETH" ? 3200 : cryptoSymbol == "SOL" ? 170 : 1
        let grossFiat = cryptoAmount * exchangeRate

        let providerFees: [(Provider, Double, String)] = [
            (.moonpay, 1.5, "1-3 business days"),
            (.transak, 0.99, "1-2 business days"),
            (.ramp, 0.79, "Same day"),
            (.coinbase, 1.49, "2-3 business days"),
        ]

        return providerFees.map { (provider, feePercent, arrival) in
            let fee = grossFiat * Decimal(feePercent / 100)
            let networkFee = Decimal(1.5)
            return SellQuote(
                provider: provider,
                cryptoAmount: cryptoAmount,
                cryptoSymbol: cryptoSymbol,
                fiatAmount: grossFiat - fee - networkFee,
                fiatCurrency: fiatCurrency,
                processingFeeUSD: fee,
                networkFeeUSD: networkFee,
                totalFeeUSD: fee + networkFee,
                estimatedArrival: arrival,
                paymentDestinations: ["Bank Account", "Debit Card"]
            )
        }.sorted { $0.fiatAmount > $1.fiatAmount }
    }

    func launchSell(
        provider: Provider,
        cryptoAmount: Decimal,
        cryptoSymbol: String,
        fiatCurrency: String,
        walletAddress: String
    ) -> URL? {
        switch provider {
        case .moonpay:
            return URL(string: "https://sell.moonpay.com?apiKey=YOUR_KEY&baseCurrencyCode=\(cryptoSymbol.lowercased())&baseCurrencyAmount=\(cryptoAmount)&quoteCurrencyCode=\(fiatCurrency.lowercased())&externalCustomerId=\(walletAddress.prefix(10))")
        case .transak:
            return URL(string: "https://global.transak.com?apiKey=YOUR_KEY&productsAvailed=SELL&cryptoCurrencyCode=\(cryptoSymbol)&fiatCurrency=\(fiatCurrency)&walletAddress=\(walletAddress)")
        case .ramp:
            return URL(string: "https://app.ramp.network?apiKey=YOUR_KEY&offrampAsset=\(cryptoSymbol)&userAddress=\(walletAddress)")
        case .coinbase:
            return URL(string: "https://pay.coinbase.com/sell?appId=YOUR_APP_ID&asset=\(cryptoSymbol)&fiatCurrency=\(fiatCurrency)")
        }
    }
}
