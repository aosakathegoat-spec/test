import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if !appState.hasCompletedOnboarding {
                OnboardingView()
                    .transition(.opacity)
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(Theme.Animation.smooth, value: appState.hasCompletedOnboarding)
        .sheet(isPresented: $appState.showPricingSheet) {
            PricingView()
                .environmentObject(appState)
        }
        .alert("Upgrade Required", isPresented: $appState.showUpgradePrompt) {
            Button("View Plans") { appState.showPricingSheet = true }
            Button("Not Now", role: .cancel) {}
        } message: {
            Text("You've reached your token limit or this feature requires a higher plan.")
        }
        .alert("Error", isPresented: $appState.showErrorAlert) {
            Button("OK") {}
        } message: {
            Text(appState.errorMessage)
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: AppTab = .chat

    var body: some View {
        ZStack(alignment: .bottom) {
            // Content
            Group {
                switch selectedTab {
                case .chat:     ChatView()
                case .inbox:    InboxView()
                case .morning:  MorningBriefingView()
                case .settings: SettingsView()
                }
            }
            .ignoresSafeArea(edges: .bottom)

            // Custom tab bar
            customTabBar
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                tabBarItem(tab)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.sm)
        .padding(.bottom, 30)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .overlay(alignment: .top) {
                    Divider()
                        .background(Color.white.opacity(0.08))
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func tabBarItem(_ tab: AppTab) -> some View {
        Button {
            withAnimation(Theme.Animation.snappy) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    if selectedTab == tab {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Theme.Colors.primary.opacity(0.15))
                            .frame(width: 52, height: 32)
                            .matchedGeometryEffect(id: "tab-bg", in: tabNamespace)
                    }

                    Image(systemName: tab.icon)
                        .font(.system(size: selectedTab == tab ? 22 : 20, weight: .semibold))
                        .foregroundStyle(
                            selectedTab == tab
                                ? Theme.Colors.gradientPrimary
                                : Color(Theme.Colors.textTertiary)
                        )
                        .frame(width: 52, height: 32)
                        .scaleEffect(selectedTab == tab ? 1.1 : 1.0)
                        .animation(Theme.Animation.spring, value: selectedTab)
                }

                Text(tab.title)
                    .font(.system(size: 10, weight: selectedTab == tab ? .semibold : .regular))
                    .foregroundStyle(
                        selectedTab == tab
                            ? Theme.Colors.primary
                            : Theme.Colors.textTertiary
                    )
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    @Namespace private var tabNamespace
}
