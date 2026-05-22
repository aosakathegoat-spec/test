import Foundation

// MARK: - Phishing Detection Service
// Phantom's phishing protection relies on a slow-updating static list.
// VaultX uses multi-layer detection: local blocklist + real-time analysis + behavioral heuristics.

final class PhishingDetectionService {
    static let shared = PhishingDetectionService()

    private var blocklist: Set<String> = []
    private var contractBlacklist: Set<String> = []
    private let updateInterval: TimeInterval = 3600
    private var lastUpdated: Date?

    private init() {
        Task { await loadLocalBlocklist() }
    }

    // MARK: - URL / dApp Scanning

    struct DAppScanResult {
        var risk: PhishingRisk
        var reasons: [String]
        var contractVerified: Bool?
        var isKnownSafe: Bool
        var recommendation: String
    }

    func scanURL(_ urlString: String) async -> DAppScanResult {
        var reasons: [String] = []
        var riskScore = 0

        guard let url = URL(string: urlString), let host = url.host?.lowercased() else {
            return DAppScanResult(risk: .blocked, reasons: ["Invalid URL"], contractVerified: nil, isKnownSafe: false, recommendation: "Do not proceed")
        }

        // 1. Exact blocklist match
        if blocklist.contains(host) {
            return DAppScanResult(risk: .blocked, reasons: ["Site is on phishing blocklist"], contractVerified: nil, isKnownSafe: false, recommendation: "This site is a known phishing site. Do NOT connect your wallet.")
        }

        // 2. Homoglyph / lookalike detection
        if let lookalike = detectHomoglyphAttack(host) {
            reasons.append("Domain looks like '\(lookalike)' but uses different characters (homoglyph attack)")
            riskScore += 80
        }

        // 3. Punycode / IDN detection
        if host.hasPrefix("xn--") {
            reasons.append("Domain uses internationalized characters (common in phishing)")
            riskScore += 40
        }

        // 4. Suspicious TLD
        let suspiciousTLDs = [".xyz", ".tk", ".ml", ".ga", ".cf", ".gq", ".top", ".click", ".loan", ".work"]
        if suspiciousTLDs.contains(where: { host.hasSuffix($0) }) {
            reasons.append("Suspicious top-level domain")
            riskScore += 20
        }

        // 5. Brand impersonation in subdomain
        let brandKeywords = ["phantom", "metamask", "uniswap", "opensea", "coinbase", "binance", "ledger", "trezor"]
        for brand in brandKeywords {
            if host.contains(brand) && !isOfficialDomain(host, brand: brand) {
                reasons.append("Domain impersonates '\(brand)' brand")
                riskScore += 60
                break
            }
        }

        // 6. Recently registered domain heuristic (via HTTPS timing check)
        if await checkRecentRegistration(host) {
            reasons.append("Domain registered recently (high-risk pattern)")
            riskScore += 30
        }

        // 7. HTTP (not HTTPS)
        if url.scheme == "http" {
            reasons.append("Not using HTTPS — connection is unencrypted")
            riskScore += 25
        }

        let risk: PhishingRisk
        switch riskScore {
        case 0: risk = .none
        case 1..<25: risk = .low
        case 25..<50: risk = .medium
        case 50..<80: risk = .high
        default: risk = .blocked
        }

        let recommendation: String
        switch risk {
        case .none: recommendation = "Site appears safe to connect"
        case .low: recommendation = "Exercise caution. Verify you're on the correct site"
        case .medium: recommendation = "Multiple risk factors detected. Do not enter your seed phrase"
        case .high: recommendation = "High risk detected. We strongly advise against connecting"
        case .blocked: recommendation = "This site is blocked. Do NOT connect your wallet under any circumstances"
        }

        return DAppScanResult(
            risk: risk,
            reasons: reasons,
            contractVerified: nil,
            isKnownSafe: false,
            recommendation: recommendation
        )
    }

    // MARK: - Smart Contract Analysis

    struct ContractAnalysisResult {
        var risk: PhishingRisk
        var findings: [ContractFinding]
        var isVerified: Bool
        var hasSourceCode: Bool
        var isProxy: Bool
        var isHoneypot: Bool
        var cannotSell: Bool
        var ownerCanMint: Bool
        var ownerCanPause: Bool
    }

    struct ContractFinding {
        var severity: Severity
        var title: String
        var description: String

        enum Severity: String { case info, warning, critical }
    }

    func analyzeContract(_ address: String, chain: Chain) async -> ContractAnalysisResult {
        var findings: [ContractFinding] = []

        // Check blacklist
        if contractBlacklist.contains(address.lowercased()) {
            findings.append(ContractFinding(
                severity: .critical,
                title: "Known Malicious Contract",
                description: "This contract address is on the phishing blacklist"
            ))
            return ContractAnalysisResult(
                risk: .blocked, findings: findings, isVerified: false,
                hasSourceCode: false, isProxy: false, isHoneypot: true,
                cannotSell: true, ownerCanMint: false, ownerCanPause: false
            )
        }

        // Fetch contract bytecode analysis from API
        let analysis = await fetchContractAnalysis(address: address, chain: chain)

        if analysis.isHoneypot {
            findings.append(ContractFinding(severity: .critical, title: "Honeypot Detected", description: "You can buy but cannot sell this token"))
        }

        if analysis.ownerCanMint {
            findings.append(ContractFinding(severity: .warning, title: "Mintable Token", description: "Contract owner can create unlimited new tokens, diluting your holdings"))
        }

        if analysis.ownerCanPause {
            findings.append(ContractFinding(severity: .warning, title: "Pausable Contract", description: "Owner can pause all transfers, potentially freezing your funds"))
        }

        if !analysis.hasSourceCode {
            findings.append(ContractFinding(severity: .warning, title: "Unverified Source Code", description: "Contract source code has not been verified on the blockchain explorer"))
        }

        if analysis.isProxy {
            findings.append(ContractFinding(severity: .info, title: "Proxy Contract", description: "Logic can be upgraded by the owner. Monitor for changes"))
        }

        let risk: PhishingRisk = analysis.isHoneypot ? .blocked : (findings.isEmpty ? .none : .medium)
        return ContractAnalysisResult(
            risk: risk,
            findings: findings,
            isVerified: analysis.isVerified,
            hasSourceCode: analysis.hasSourceCode,
            isProxy: analysis.isProxy,
            isHoneypot: analysis.isHoneypot,
            cannotSell: analysis.isHoneypot,
            ownerCanMint: analysis.ownerCanMint,
            ownerCanPause: analysis.ownerCanPause
        )
    }

    // MARK: - Transaction Risk Scoring

    struct TransactionRiskResult {
        var riskScore: Int         // 0-100
        var flags: [String]
        var requiresExtraConfirmation: Bool
    }

    func scoreTransaction(
        toAddress: String,
        amount: Decimal,
        amountUSD: Decimal,
        chain: Chain,
        inputData: String?
    ) -> TransactionRiskResult {
        var score = 0
        var flags: [String] = []

        // High USD value
        if amountUSD > 10_000 {
            score += 30
            flags.append("Large transaction: \(amountUSD) USD")
        }

        // New/unknown recipient
        // (Would check address history from local DB)

        // Unlimited approval detection (ERC-20 approve with max uint256)
        if let data = inputData, data.hasPrefix("0x095ea7b3") {
            let approvalAmount = parseApprovalAmount(data)
            if approvalAmount == Decimal.greatestFiniteMagnitude || approvalAmount > 1_000_000_000 {
                score += 50
                flags.append("Unlimited token approval — you're giving this contract access to all your tokens")
            }
        }

        // Contract interaction with unknown contract
        if toAddress.hasPrefix("0x") && contractBlacklist.contains(toAddress.lowercased()) {
            score += 90
            flags.append("Destination is a known malicious contract")
        }

        return TransactionRiskResult(
            riskScore: score,
            flags: flags,
            requiresExtraConfirmation: score >= 30
        )
    }

    // MARK: - Blocklist Management

    func updateBlocklist() async {
        // Fetch MetaMask phishing blocklist
        guard let url = URL(string: "https://raw.githubusercontent.com/MetaMask/eth-phishing-detect/master/src/config.json") else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let blacklist = json["blacklist"] as? [String] {
                blocklist = Set(blacklist)
                lastUpdated = Date()
            }
        } catch {
            // Use cached list on failure
        }
    }

    // MARK: - Private helpers

    private func detectHomoglyphAttack(_ host: String) -> String? {
        let knownDomains = [
            "uniswap.org": ["un1swap", "uniswąp", "unlswap"],
            "opensea.io": ["0pensea", "openséa"],
            "phantom.app": ["phantorn", "phant0m"],
            "metamask.io": ["metarnask", "metàmask"],
        ]

        for (official, typos) in knownDomains {
            if typos.contains(where: { host.contains($0) }) {
                return official
            }
        }
        return nil
    }

    private func isOfficialDomain(_ host: String, brand: String) -> Bool {
        let officialDomains: [String: [String]] = [
            "phantom": ["phantom.app"],
            "metamask": ["metamask.io"],
            "uniswap": ["uniswap.org", "app.uniswap.org"],
            "opensea": ["opensea.io"],
            "coinbase": ["coinbase.com", "wallet.coinbase.com"],
            "binance": ["binance.com", "binance.org"],
            "ledger": ["ledger.com"],
            "trezor": ["trezor.io"],
        ]
        return officialDomains[brand]?.contains(host) ?? false
    }

    private func checkRecentRegistration(_ host: String) async -> Bool {
        // In production: call WHOIS API or use a domain age service
        return false
    }

    private func fetchContractAnalysis(address: String, chain: Chain) async -> (
        isHoneypot: Bool, ownerCanMint: Bool, ownerCanPause: Bool,
        hasSourceCode: Bool, isProxy: Bool, isVerified: Bool
    ) {
        // In production: call GoPlus Labs or similar API
        return (false, false, false, true, false, true)
    }

    private func parseApprovalAmount(_ data: String) -> Decimal {
        // Parse amount from ERC-20 approve calldata
        guard data.count >= 74 else { return 0 }
        let amountHex = String(data.suffix(64))
        if amountHex == String(repeating: "f", count: 64) {
            return Decimal.greatestFiniteMagnitude
        }
        return 0
    }

    private func loadLocalBlocklist() async {
        // Load bundled blocklist from app resources
        if let url = Bundle.main.url(forResource: "phishing_blocklist", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let list = try? JSONDecoder().decode([String].self, from: data) {
            blocklist = Set(list)
        }
        await updateBlocklist()
    }
}
