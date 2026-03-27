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

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            ChatView()
                .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right.fill") }
                .tag(AppState.Tab.chat)

            LiveAgentsView()
                .tabItem { Label("Agents", systemImage: "bolt.fill") }
                .tag(AppState.Tab.agents)

            SessionsView()
                .tabItem { Label("Sessions", systemImage: "list.bullet.rectangle.portrait.fill") }
                .tag(AppState.Tab.sessions)

            CronView()
                .tabItem { Label("Cron", systemImage: "clock.fill") }
                .tag(AppState.Tab.cron)

            NodesView()
                .tabItem { Label("Nodes", systemImage: "antenna.radiowaves.left.and.right") }
                .tag(AppState.Tab.nodes)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(AppState.Tab.settings)
        }
        .tint(.orange)
    }
}
