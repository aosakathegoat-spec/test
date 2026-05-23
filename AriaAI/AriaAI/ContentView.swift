import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var auth: AuthService
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if !auth.isLoggedIn {
                LoginView()
                    .transition(.opacity)
            } else if !auth.hasEnteredAge {
                AgeEntryView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal:   .move(edge: .leading).combined(with: .opacity)
                    ))
            } else if !appState.hasCompletedOnboarding {
                OnboardingView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal:   .move(edge: .leading).combined(with: .opacity)
                    ))
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: auth.isLoggedIn)
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: auth.hasEnteredAge)
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: appState.hasCompletedOnboarding)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { appState.tokenTracker.refreshReset() }
        }
        .sheet(isPresented: $appState.showPricingSheet) {
            PricingView().environmentObject(appState)
        }
        .alert("Upgrade Required", isPresented: $appState.showUpgradePrompt) {
            Button("View Plans")     { appState.showPricingSheet = true }
            Button("Not Now", role: .cancel) {}
        } message: {
            Text("You've reached your daily token limit or this feature requires a higher plan.")
        }
        .alert("Error", isPresented: $appState.showErrorAlert) {
            Button("OK") {}
        } message: {
            Text(appState.errorMessage)
        }
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: AppTab = .chat
    @Namespace private var tabNS

    var body: some View {
        ZStack(alignment: .bottom) {
            // Single shared background — avoids running 4 animation loops (one per always-live tab view).
            LiquidGlassBackground()
                .ignoresSafeArea()

            // Keep all tab views alive so their ViewModels survive tab switches.
            // Opacity + allowsHitTesting replaces switch/recreate pattern.
            ZStack {
                ChatView()
                    .opacity(selectedTab == .chat ? 1 : 0)
                    .allowsHitTesting(selectedTab == .chat)
                BlocksView()
                    .opacity(selectedTab == .blocks ? 1 : 0)
                    .allowsHitTesting(selectedTab == .blocks)
                InboxView()
                    .opacity(selectedTab == .inbox ? 1 : 0)
                    .allowsHitTesting(selectedTab == .inbox)
                MorningBriefingView()
                    .opacity(selectedTab == .morning ? 1 : 0)
                    .allowsHitTesting(selectedTab == .morning)
                SettingsView()
                    .opacity(selectedTab == .settings ? 1 : 0)
                    .allowsHitTesting(selectedTab == .settings)
            }
            .animation(.easeOut(duration: 0.18), value: selectedTab)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(edges: .bottom)
            .onChange(of: selectedTab) { _, _ in
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
            }

            // Glass tab bar
            tabBar
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                tabItem(tab)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 10)
        .padding(.bottom, 30)
        .background {
            ZStack {
                // Blur base
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                // Top separator
                VStack {
                    Divider()
                        .background(Color.white.opacity(0.1))
                    Spacer()
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    private func tabItem(_ tab: AppTab) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
            }
            let gen = UIImpactFeedbackGenerator(style: .soft)
            gen.prepare()
            gen.impactOccurred()
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    if selectedTab == tab {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#4F8EF7").opacity(0.2), Color(hex: "#9B6DFF").opacity(0.15)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 52, height: 32)
                            .matchedGeometryEffect(id: "tab_bg", in: tabNS)
                    }

                    Image(systemName: tab.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .symbolEffect(.bounce, value: selectedTab == tab)
                        .foregroundStyle(
                            selectedTab == tab
                                ? AnyShapeStyle(Theme.Colors.gradientPrimary)
                                : AnyShapeStyle(Theme.Colors.textTertiary)
                        )
                        .frame(width: 52, height: 32)
                        .scaleEffect(selectedTab == tab ? 1.08 : 1.0)
                        .animation(.spring(response: 0.25, dampingFraction: 0.65), value: selectedTab == tab)
                }

                Text(tab.title)
                    .font(.system(size: 10, weight: selectedTab == tab ? .semibold : .regular))
                    .foregroundStyle(
                        selectedTab == tab ? Theme.Colors.primary : Theme.Colors.textTertiary
                    )
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(selectedTab == tab ? [.isSelected] : [])
    }
}
