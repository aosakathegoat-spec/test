import SwiftUI

struct TokenApprovalManagerView: View {
    @EnvironmentObject var walletManager: WalletManager
    @State private var approvals: [TokenApprovalItem] = []
    @State private var isLoading = false
    @State private var selectedChain: Chain = .ethereum
    @State private var revokingId: UUID?
    @State private var revokedIds: Set<UUID> = []
    @State private var filterRisk: RiskFilter = .all

    enum RiskFilter: String, CaseIterable {
        case all = "All"
        case critical = "Critical"
        case high = "High"
        case medium = "Medium"
    }

    struct TokenApprovalItem: Identifiable {
        let id = UUID()
        var tokenSymbol: String
        var tokenAddress: String
        var spender: String
        var spenderName: String?
        var allowance: String
        var isUnlimited: Bool
        var chain: Chain
        var approvedAt: Date?
        var risk: ApprovalRisk

        enum ApprovalRisk {
            case critical, high, medium, low
            var color: Color {
                switch self {
                case .critical: return .red
                case .high: return .orange
                case .medium: return .yellow
                case .low: return .green
                }
            }
            var label: String {
                switch self {
                case .critical: return "Critical"
                case .high: return "High"
                case .medium: return "Medium"
                case .low: return "Low"
                }
            }
        }
    }

    var filteredApprovals: [TokenApprovalItem] {
        let chain = approvals.filter { $0.chain == selectedChain && !revokedIds.contains($0.id) }
        switch filterRisk {
        case .all: return chain
        case .critical: return chain.filter { $0.risk == .critical }
        case .high: return chain.filter { $0.risk == .high }
        case .medium: return chain.filter { $0.risk == .medium }
        }
    }

    var criticalCount: Int { approvals.filter { $0.risk == .critical && !revokedIds.contains($0.id) }.count }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 0) {
                    if criticalCount > 0 { criticalBanner }
                    chainFilter
                    riskFilter
                    if isLoading {
                        Spacer()
                        ProgressView("Scanning approvals…").tint(.purple).foregroundColor(.gray)
                        Spacer()
                    } else if filteredApprovals.isEmpty {
                        emptyState
                    } else {
                        approvalsList
                    }
                }
            }
            .navigationTitle("Token Approvals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { scanButton }
        }
        .preferredColorScheme(.dark)
        .task { await loadApprovals() }
    }

    // MARK: - Critical Banner

    private var criticalBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(criticalCount) Critical Risk Approval\(criticalCount == 1 ? "" : "s")")
                    .font(.caption.bold()).foregroundColor(.white)
                Text("Unlimited approvals to unknown contracts detected")
                    .font(.caption2).foregroundColor(.red.opacity(0.8))
            }
            Spacer()
        }
        .padding(.horizontal).padding(.vertical, 10)
        .background(Color.red.opacity(0.12))
    }

    // MARK: - Filters

    private var chainFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach([Chain.ethereum, .arbitrum, .optimism, .base, .polygon, .bsc], id: \.self) { chain in
                    Button(chain.displayName) { selectedChain = chain }
                        .font(.caption.bold())
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(selectedChain == chain ? Color.purple.opacity(0.3) : Color.white.opacity(0.07))
                        .foregroundColor(selectedChain == chain ? .purple : .gray)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 10)
    }

    private var riskFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(RiskFilter.allCases, id: \.self) { f in
                    Button(f.rawValue) { filterRisk = f }
                        .font(.caption.bold())
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(filterRisk == f ? Color.white.opacity(0.15) : Color.clear)
                        .foregroundColor(filterRisk == f ? .white : .gray)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(filterRisk == f ? Color.white.opacity(0.3) : Color.clear, lineWidth: 1))
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 4)
    }

    // MARK: - Approvals List

    private var approvalsList: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(filteredApprovals) { item in
                    ApprovalItemCard(item: item, isRevoking: revokingId == item.id) {
                        Task { await revokeApproval(item) }
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 56)).foregroundColor(.green.opacity(0.6))
            Text("No Approvals Found").font(.title3.bold()).foregroundColor(.white)
            Text("Your wallets have no active token approvals on this chain")
                .font(.subheadline).foregroundColor(.gray).multilineTextAlignment(.center).padding(.horizontal)
            Spacer()
        }
    }

    // MARK: - Toolbar

    private var scanButton: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: { Task { await loadApprovals() } }) {
                Image(systemName: "magnifyingglass").foregroundColor(.purple)
            }
        }
    }

    // MARK: - Data Loading (mock)

    private func loadApprovals() async {
        await MainActor.run { isLoading = true }
        try? await Task.sleep(nanoseconds: 800_000_000)
        let mock: [TokenApprovalItem] = [
            .init(tokenSymbol: "USDC", tokenAddress: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", spender: "0x1111111254EEB25477B68fb85Ed929f73A960582", spenderName: "1inch Router", allowance: "Unlimited", isUnlimited: true, chain: .ethereum, approvedAt: Calendar.current.date(byAdding: .day, value: -30, to: Date()), risk: .critical),
            .init(tokenSymbol: "WETH", tokenAddress: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", spender: "0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45", spenderName: "Uniswap V3", allowance: "Unlimited", isUnlimited: true, chain: .ethereum, approvedAt: Calendar.current.date(byAdding: .day, value: -60, to: Date()), risk: .high),
            .init(tokenSymbol: "USDT", tokenAddress: "0xdAC17F958D2ee523a2206206994597C13D831ec7", spender: "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D", spenderName: "Uniswap V2", allowance: "Unlimited", isUnlimited: true, chain: .ethereum, approvedAt: Calendar.current.date(byAdding: .day, value: -90, to: Date()), risk: .medium),
            .init(tokenSymbol: "DAI", tokenAddress: "0x6B175474E89094C44Da98b954EedeAC495271d0F", spender: "0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B", spenderName: "Compound", allowance: "500.00", isUnlimited: false, chain: .ethereum, approvedAt: Calendar.current.date(byAdding: .day, value: -14, to: Date()), risk: .low),
            .init(tokenSymbol: "USDC", tokenAddress: "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", spender: "0x1111111254EEB25477B68fb85Ed929f73A960582", spenderName: "1inch Router", allowance: "Unlimited", isUnlimited: true, chain: .polygon, approvedAt: Calendar.current.date(byAdding: .day, value: -5, to: Date()), risk: .high),
        ]
        await MainActor.run {
            approvals = mock
            isLoading = false
        }
    }

    private func revokeApproval(_ item: TokenApprovalItem) async {
        await MainActor.run { revokingId = item.id }
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        await MainActor.run {
            revokedIds.insert(item.id)
            revokingId = nil
        }
    }
}

// MARK: - Approval Item Card

struct ApprovalItemCard: View {
    var item: TokenApprovalManagerView.TokenApprovalItem
    var isRevoking: Bool
    var onRevoke: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(item.risk.color.opacity(0.15)).frame(width: 44, height: 44)
                    Text(String(item.tokenSymbol.prefix(2)))
                        .font(.caption.bold()).foregroundColor(item.risk.color)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(item.tokenSymbol).font(.subheadline.bold()).foregroundColor(.white)
                        Text(item.risk.label)
                            .font(.caption2.bold())
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(item.risk.color.opacity(0.15))
                            .foregroundColor(item.risk.color)
                            .clipShape(Capsule())
                        if item.isUnlimited {
                            Text("∞ Unlimited")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.red.opacity(0.1))
                                .foregroundColor(.red)
                                .clipShape(Capsule())
                        }
                    }
                    Text(item.spenderName ?? shortAddress(item.spender))
                        .font(.caption).foregroundColor(.gray)
                }
                Spacer()
                Button(action: onRevoke) {
                    if isRevoking {
                        ProgressView().tint(.red).scaleEffect(0.8)
                    } else {
                        Text("Revoke").font(.caption.bold()).foregroundColor(.red)
                    }
                }
                .frame(width: 60, height: 32)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .disabled(isRevoking)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Spender").font(.caption2).foregroundColor(.gray)
                    Text(shortAddress(item.spender)).font(.caption2.monospaced()).foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                if let date = item.approvedAt {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Approved").font(.caption2).foregroundColor(.gray)
                        Text(date, style: .date).font(.caption2).foregroundColor(.white.opacity(0.6))
                    }
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(item.risk == .critical ? Color.red.opacity(0.3) : Color.clear, lineWidth: 1))
    }

    private func shortAddress(_ addr: String) -> String {
        guard addr.count > 10 else { return addr }
        return "\(addr.prefix(6))…\(addr.suffix(4))"
    }
}
