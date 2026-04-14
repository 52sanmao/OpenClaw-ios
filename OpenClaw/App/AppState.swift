import SwiftUI

@MainActor
final class AppState: ObservableObject {
    enum Tab: String, CaseIterable {
        case chat, agents, sessions, cron, nodes, settings

        var label: String {
            switch self {
            case .chat: "聊天"
            case .agents: "代理"
            case .sessions: "会话"
            case .cron: "定时任务"
            case .nodes: "节点"
            case .settings: "设置"
            }
        }

        var icon: String {
            switch self {
            case .chat: "bubble.left.and.bubble.right.fill"
            case .agents: "bolt.fill"
            case .sessions: "list.bullet.rectangle.portrait.fill"
            case .cron: "clock.fill"
            case .nodes: "antenna.radiowaves.left.and.right"
            case .settings: "gearshape.fill"
            }
        }
    }

    @Published var selectedTab: Tab = .chat
    @Published var isConnecting = false
}
