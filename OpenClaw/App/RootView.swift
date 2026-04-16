import SwiftUI
import UIKit

struct RootView: View {
    @EnvironmentObject var gateway: GatewayClient
    @EnvironmentObject var appState: AppState
    @State private var showLogViewer = false
    @State private var copyNotice = false

    var body: some View {
        Group {
            if gateway.connectionState == .connected {
                MainTabView()
            } else {
                ConnectView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: gateway.connectionState)
        .overlay(alignment: .bottomTrailing) {
            Button {
                showLogViewer = true
            } label: {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(Color.ocPrimary)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 6)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 96)
            .accessibilityLabel("查看日志")
        }
        .sheet(isPresented: $showLogViewer) {
            FloatingLogViewer(
                title: "开放爪日志",
                exportText: gateway.debugLogExportText,
                entries: gateway.debugLog,
                onCopy: {
                    UIPasteboard.general.string = gateway.debugLogExportText
                    copyNotice = true
                },
                onClear: {
                    gateway.clearDebugLog()
                }
            )
            .presentationDetents([.medium, .large])
        }
        .alert("已复制日志", isPresented: $copyNotice) {
            Button("确定", role: .cancel) {}
        } message: {
            Text("复制内容已包含 App 名称、版本和日志。")
        }
    }
}

private struct FloatingLogViewer: View {
    let title: String
    let exportText: String
    let entries: [String]
    let onCopy: () -> Void
    let onClear: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(exportText)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    if entries.isEmpty {
                        Text("暂无日志")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("清空") {
                        onClear()
                    }
                    Button("复制") {
                        onCopy()
                    }
                }
            }
        }
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
            .tabItem { Label("聊天", systemImage: "bubble.left.and.bubble.right.fill") }
            .tag(AppState.Tab.chat)

            NavigationStack {
                LiveAgentsView()
            }
            .tabItem { Label("代理", systemImage: "bolt.fill") }
            .tag(AppState.Tab.agents)

            NavigationStack {
                SessionsView()
            }
            .tabItem { Label("会话", systemImage: "list.bullet.rectangle.portrait.fill") }
            .tag(AppState.Tab.sessions)

            NavigationStack {
                CronView()
            }
            .tabItem { Label("定时任务", systemImage: "clock.fill") }
            .tag(AppState.Tab.cron)

            NavigationStack {
                NodesView()
            }
            .tabItem { Label("节点", systemImage: "antenna.radiowaves.left.and.right") }
            .tag(AppState.Tab.nodes)

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("设置", systemImage: "gearshape.fill") }
            .tag(AppState.Tab.settings)
        }
        .tint(.ocPrimary)
    }
}
