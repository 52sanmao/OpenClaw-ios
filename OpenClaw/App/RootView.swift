import SwiftUI

struct RootView: View {
    @EnvironmentObject var gateway: GatewayClient
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if gateway.connectionState == .connected {
                MainTabView()
            } else {
                ConnectView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: gateway.connectionState)
    }
}

struct MainTabView: View {
    @EnvironmentObject var appState: AppState

    init() {
        // Glassmorphic tab bar
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.85)
        appearance.backgroundEffect = UIBlurEffect(style: .systemThinMaterialDark)

        // Normal state
        let normal = UITabBarItemAppearance()
        normal.normal.iconColor = UIColor(white: 0.45, alpha: 1)
        normal.normal.titleTextAttributes = [
            .foregroundColor: UIColor(white: 0.45, alpha: 1),
            .font: UIFont.systemFont(ofSize: 10, weight: .bold),
            .kern: 1.5
        ]

        // Selected state
        normal.selected.iconColor = UIColor(red: 1, green: 0.57, blue: 0.35, alpha: 1)
        normal.selected.titleTextAttributes = [
            .foregroundColor: UIColor(red: 1, green: 0.57, blue: 0.35, alpha: 1),
            .font: UIFont.systemFont(ofSize: 10, weight: .bold),
            .kern: 1.5
        ]

        appearance.stackedLayoutAppearance = normal
        appearance.inlineLayoutAppearance = normal
        appearance.compactInlineLayoutAppearance = normal

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            NavigationStack {
                ChatView()
            }
            .tabItem { Label("CHAT", systemImage: "bubble.left.and.bubble.right.fill") }
            .tag(AppState.Tab.chat)

            NavigationStack {
                LiveAgentsView()
            }
            .tabItem { Label("AGENTS", systemImage: "bolt.fill") }
            .tag(AppState.Tab.agents)

            NavigationStack {
                SessionsView()
            }
            .tabItem { Label("SESSIONS", systemImage: "list.bullet.rectangle.portrait.fill") }
            .tag(AppState.Tab.sessions)

            NavigationStack {
                CronView()
            }
            .tabItem { Label("CRON", systemImage: "clock.fill") }
            .tag(AppState.Tab.cron)

            NavigationStack {
                NodesView()
            }
            .tabItem { Label("NODES", systemImage: "antenna.radiowaves.left.and.right") }
            .tag(AppState.Tab.nodes)

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("SETTINGS", systemImage: "gearshape.fill") }
            .tag(AppState.Tab.settings)
        }
        .tint(.ocPrimary)
    }
}
