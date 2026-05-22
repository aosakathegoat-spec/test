import Foundation

// MARK: - Network Service — all blockchain RPC calls

final class NetworkService {
    static let shared = NetworkService()
    private let session: URLSession
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        session = URLSession(configuration: config)
    }

    // MARK: - Balance Fetching

    func fetchBalance(wallet: Wallet) async throws -> WalletBalance {
        switch wallet.chain {
        case .ethereum, .bsc, .polygon, .arbitrum, .optimism, .base, .avalanche, .fantom:
            return try await fetchEVMBalance(address: wallet.address, chain: wallet.chain)
        case .bitcoin, .bitcoinTestnet:
            return try await fetchBitcoinBalance(address: wallet.address, chain: wallet.chain)
        case .solana:
            return try await fetchSolanaBalance(address: wallet.address)
        }
    }

    // MARK: - EVM Balance (eth_getBalance + token balances via multicall)

    private func fetchEVMBalance(address: String, chain: Chain) async throws -> WalletBalance {
        let rpcURL = rpcURL(for: chain)

        // eth_getBalance
        let nativeBalance = try await ethGetBalance(address: address, rpcURL: rpcURL)

        // ERC-20 token balances — use Alchemy/Moralis token API in production
        let tokens: [TokenBalance] = []

        // NFTs — use Alchemy NFT API
        let nfts: [NFTAsset] = []

        let ethPrice = try await fetchPrice(symbol: chain.nativeCurrency)

        return WalletBalance(
            nativeAmount: nativeBalance,
            nativeSymbol: chain.nativeCurrency,
            usdValue: nativeBalance * ethPrice,
            tokens: tokens,
            nfts: nfts,
            updatedAt: Date()
        )
    }

    private func ethGetBalance(address: String, rpcURL: String) async throws -> Decimal {
        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "eth_getBalance",
            "params": [address, "latest"],
            "id": 1,
        ]

        let result = try await jsonRPC(url: rpcURL, body: body)

        guard let hexString = result["result"] as? String else {
            throw NetworkError.invalidResponse
        }

        let cleanHex = hexString.hasPrefix("0x") ? String(hexString.dropFirst(2)) : hexString
        guard let wei = UInt64(cleanHex, radix: 16) else { return 0 }

        // Convert wei to ETH (divide by 1e18)
        return Decimal(wei) / Decimal(1_000_000_000_000_000_000)
    }

    // MARK: - Bitcoin Balance (blockchain.info / electrum)

    private func fetchBitcoinBalance(address: String, chain: Chain) async throws -> WalletBalance {
        let urlString = "https://blockchain.info/rawaddr/\(address)?limit=0"
        guard let url = URL(string: urlString) else { throw NetworkError.invalidURL }

        let (data, _) = try await session.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        let satoshis = json?["final_balance"] as? Int64 ?? 0
        let btc = Decimal(satoshis) / 100_000_000
        let btcPrice = try await fetchPrice(symbol: "BTC")

        // Fetch Ordinals and BRC-20 if taproot address (bc1p...)
        var nfts: [NFTAsset] = []
        var brc20Tokens: [TokenBalance] = []

        if address.hasPrefix("bc1p") {
            nfts = await fetchOrdinals(address: address)
            brc20Tokens = await fetchBRC20Tokens(address: address)
        }

        return WalletBalance(
            nativeAmount: btc,
            nativeSymbol: "BTC",
            usdValue: btc * btcPrice,
            tokens: brc20Tokens,
            nfts: nfts,
            updatedAt: Date()
        )
    }

    // MARK: - Ordinals & BRC-20 (features unique to VaultX vs Phantom)

    private func fetchOrdinals(address: String) async -> [NFTAsset] {
        // In production: call Ordinals API (ordinals.com or hiro.so)
        guard let url = URL(string: "https://api.hiro.so/ordinals/v1/inscriptions?address=\(address)") else { return [] }

        do {
            let (data, _) = try await session.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let results = json?["results"] as? [[String: Any]] ?? []

            return results.map { inscription in
                NFTAsset(
                    id: UUID(),
                    contractAddress: "ordinals",
                    tokenId: inscription["id"] as? String ?? "",
                    name: "Ordinal #\(inscription["number"] as? Int ?? 0)",
                    imageURL: inscription["content_uri"] as? String,
                    collectionName: "Bitcoin Ordinals",
                    isOrdinal: true,
                    inscriptionId: inscription["id"] as? String
                )
            }
        } catch {
            return []
        }
    }

    private func fetchBRC20Tokens(address: String) async -> [TokenBalance] {
        // In production: call BRC-20 indexer API
        guard let url = URL(string: "https://api.hiro.so/ordinals/v1/brc-20/balances?address=\(address)") else { return [] }

        do {
            let (data, _) = try await session.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let results = json?["results"] as? [[String: Any]] ?? []

            return results.map { token in
                TokenBalance(
                    id: UUID(),
                    contractAddress: "brc20:\(token["ticker"] as? String ?? "")",
                    symbol: token["ticker"] as? String ?? "",
                    name: token["ticker"] as? String ?? "",
                    decimals: 18,
                    balance: Decimal(string: token["overall_balance"] as? String ?? "0") ?? 0,
                    usdValue: 0,
                    isBRC20: true
                )
            }
        } catch {
            return []
        }
    }

    // MARK: - Solana Balance

    private func fetchSolanaBalance(address: String) async throws -> WalletBalance {
        let rpcURL = "https://api.mainnet-beta.solana.com"
        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "method": "getBalance",
            "params": [address],
        ]

        let result = try await jsonRPC(url: rpcURL, body: body)
        let lamports = (result["result"] as? [String: Any])?["value"] as? Int64 ?? 0
        let sol = Decimal(lamports) / 1_000_000_000

        let solPrice = try await fetchPrice(symbol: "SOL")

        return WalletBalance(
            nativeAmount: sol,
            nativeSymbol: "SOL",
            usdValue: sol * solPrice,
            tokens: [],
            nfts: [],
            updatedAt: Date()
        )
    }

    // MARK: - Transaction History

    func fetchTransactions(wallet: Wallet, page: Int = 0) async throws -> [Transaction] {
        // In production: use Alchemy/Moralis for EVM, blockchain.info for BTC
        return []
    }

    // MARK: - Transaction Broadcast

    func broadcastTransaction(signedTxHex: String, chain: Chain) async throws -> String {
        let rpcURL = rpcURL(for: chain)

        if chain.isEVM {
            let body: [String: Any] = [
                "jsonrpc": "2.0",
                "method": "eth_sendRawTransaction",
                "params": [signedTxHex],
                "id": 1,
            ]
            let result = try await jsonRPC(url: rpcURL, body: body)
            guard let txHash = result["result"] as? String else {
                throw NetworkError.broadcastFailed(result["error"] as? String ?? "Unknown error")
            }
            return txHash
        }

        if chain == .bitcoin || chain == .bitcoinTestnet {
            guard let url = URL(string: "https://blockchain.info/pushtx") else {
                throw NetworkError.invalidURL
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = "tx=\(signedTxHex)".data(using: .utf8)
            let (_, response) = try await session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw NetworkError.broadcastFailed("Broadcast failed")
            }
            return "Broadcast successful"
        }

        throw NetworkError.unsupportedChain
    }

    // MARK: - Multi-Sig Deployment

    func deployMultiSigWallet(chain: Chain, signers: [String], required: Int) async throws -> String {
        // In production: deploy Gnosis Safe for EVM chains
        // For Bitcoin: construct P2SH/P2WSH redeem script
        if chain.isEVM {
            return "0x\(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(40))"
        }
        throw NetworkError.unsupportedChain
    }

    // MARK: - Price Feed

    func fetchPrice(symbol: String) async throws -> Decimal {
        let id = coinGeckoId(for: symbol)
        guard let url = URL(string: "https://api.coingecko.com/api/v3/simple/price?ids=\(id)&vs_currencies=usd") else {
            throw NetworkError.invalidURL
        }

        let (data, _) = try await session.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let price = (json?[id] as? [String: Any])?["usd"] as? Double ?? 0
        return Decimal(price)
    }

    func fetchPrices(symbols: [String]) async throws -> [String: Decimal] {
        let ids = symbols.map { coinGeckoId(for: $0) }.joined(separator: ",")
        guard let url = URL(string: "https://api.coingecko.com/api/v3/simple/price?ids=\(ids)&vs_currencies=usd&include_24hr_change=true") else {
            throw NetworkError.invalidURL
        }

        let (data, _) = try await session.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

        var result: [String: Decimal] = [:]
        for symbol in symbols {
            let id = coinGeckoId(for: symbol)
            if let priceDouble = (json[id] as? [String: Any])?["usd"] as? Double {
                result[symbol] = Decimal(priceDouble)
            }
        }
        return result
    }

    // MARK: - Gas Estimation

    func estimateGas(chain: Chain, from: String, to: String, data: String?) async throws -> GasEstimate {
        let rpcURL = rpcURL(for: chain)

        var params: [String: Any] = ["from": from, "to": to]
        if let data { params["data"] = data }

        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "eth_estimateGas",
            "params": [params],
            "id": 1,
        ]

        let result = try await jsonRPC(url: rpcURL, body: body)
        let hexGas = result["result"] as? String ?? "0x5208"
        let gasLimit = UInt64(hexGas.dropFirst(2), radix: 16) ?? 21000

        // Get gas price
        let gasPriceBody: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "eth_gasPrice",
            "params": [],
            "id": 2,
        ]
        let gasPriceResult = try await jsonRPC(url: rpcURL, body: gasPriceBody)
        let hexGasPrice = gasPriceResult["result"] as? String ?? "0x3B9ACA00"
        let gasPriceGwei = UInt64(hexGasPrice.dropFirst(2), radix: 16) ?? 1_000_000_000

        let nativePrice = try await fetchPrice(symbol: chain.nativeCurrency)
        let feeGwei = Decimal(gasLimit) * Decimal(gasPriceGwei) / 1_000_000_000
        let feeEth = feeGwei / 1_000_000_000
        let feeUSD = feeEth * nativePrice

        return GasEstimate(gasLimit: gasLimit, gasPriceGwei: gasPriceGwei, estimatedFeeUSD: feeUSD)
    }

    // MARK: - Private Helpers

    private func jsonRPC(url: String, body: [String: Any]) async throws -> [String: Any] {
        guard let urlObj = URL(string: url) else { throw NetworkError.invalidURL }

        var request = URLRequest(url: urlObj)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await session.data(for: request)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }

    private func rpcURL(for chain: Chain) -> String {
        switch chain {
        case .ethereum: return "https://eth-mainnet.g.alchemy.com/v2/your-key"
        case .bsc: return "https://bsc-dataseed.binance.org/"
        case .polygon: return "https://polygon-rpc.com/"
        case .arbitrum: return "https://arb1.arbitrum.io/rpc"
        case .optimism: return "https://mainnet.optimism.io"
        case .base: return "https://mainnet.base.org"
        case .avalanche: return "https://api.avax.network/ext/bc/C/rpc"
        case .fantom: return "https://rpc.ftm.tools/"
        default: return "https://eth-mainnet.g.alchemy.com/v2/your-key"
        }
    }

    private func coinGeckoId(for symbol: String) -> String {
        let map = [
            "BTC": "bitcoin", "ETH": "ethereum", "SOL": "solana",
            "BNB": "binancecoin", "MATIC": "matic-network",
            "AVAX": "avalanche-2", "FTM": "fantom",
        ]
        return map[symbol.uppercased()] ?? symbol.lowercased()
    }
}

// MARK: - Supporting Types

struct GasEstimate {
    var gasLimit: UInt64
    var gasPriceGwei: UInt64
    var estimatedFeeUSD: Decimal
}

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case broadcastFailed(String)
    case unsupportedChain
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response from node"
        case .broadcastFailed(let msg): return "Broadcast failed: \(msg)"
        case .unsupportedChain: return "Chain not supported for this operation"
        case .rateLimited: return "Rate limited — please try again"
        }
    }
}
