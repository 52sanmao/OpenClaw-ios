import SwiftUI

struct HealthView: View {
    @EnvironmentObject var gateway: GatewayClient
    @State private var sessionCount = 0
    @State private var isLoading = false

    var body: some View {
        ZStack {
            Color.surfaceBase.ignoresSafeArea()
            BlueprintGrid()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // IronClaw
                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel(text: "IronClaw")

                        VStack(spacing: 0) {
                            SettingsRow(label: "版本", value: gateway.serverVersion)
                            SettingsRow(label: "主机", value: gateway.serverHost)
                            SettingsRow(label: "状态", value: "运行中", valueColor: Color.ocSuccess)
                        }
                        .vanguardCard()
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel(text: "会话")

                        VStack(spacing: 0) {
                            SettingsRow(label: "活动会话数", value: "\(sessionCount)")
                            SettingsRow(label: "连接方式", value: "IronClaw 线程接口")
                            SettingsRow(label: "聊天链路", value: "/api/chat/thread/new · /api/chat/send · /api/chat/history", valueColor: Color.ocSuccess)
                        }
                        .vanguardCard()
                    }

                    // Usage
                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel(text: "使用量")

                        NavigationLink {
                            UsageView()
                        } label: {
                            HStack {
                                Image(systemName: "chart.bar.fill")
                                    .foregroundStyle(Color.ocPrimary)
                                Text("会话概览")
                                    .font(.body(14, weight: .medium))
                                    .foregroundStyle(Color.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(Color.textTertiary)
                            }
                            .padding(14)
                            .vanguardCard()
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
        }
        .navigationTitle("健康状态")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await loadHealth() } } label: {
                    Image(systemName: "arrow.clockwise").foregroundStyle(Color.ocPrimary)
                }
            }
        }
        .task { await loadHealth() }
    }

    private func loadHealth() async {
        isLoading = true
        defer { isLoading = false }
        if let response = try? await gateway.sendRequest(method: "sessions.list", params: ["limit": 100]),
           response.ok,
           let payload = response.payload?.dict,
           let sessions = payload["sessions"] as? [[String: Any]] {
            sessionCount = sessions.count
        }
    }
}

struct UsageView: View {
    @EnvironmentObject var gateway: GatewayClient
    @State private var usageData: [[String: Any]] = []

    var body: some View {
        ZStack {
            Color.surfaceBase.ignoresSafeArea()
            BlueprintGrid()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(text: "令牌使用量")
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    if usageData.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "chart.bar")
                                .font(.system(size: 40))
                                .foregroundStyle(Color.textTertiary)
                            Text("暂无使用数据")
                                .font(.label(11, weight: .bold))
                                .tracking(2)
                                .foregroundStyle(Color.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(Array(usageData.enumerated()), id: \.offset) { _, session in
                                let key = session["key"] as? String ?? "未知"
                                let input = session["inputTokens"] as? Int ?? 0
                                let output = session["outputTokens"] as? Int ?? 0

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(key)
                                        .font(.body(13, weight: .semibold))
                                        .foregroundStyle(Color.textPrimary)
                                        .lineLimit(1)
                                    HStack(spacing: 16) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.right")
                                                .font(.system(size: 9))
                                            Text("\(input)")
                                                .font(.label(11))
                                        }
                                        .foregroundStyle(Color.textTertiary)
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.left")
                                                .font(.system(size: 9))
                                            Text("\(output)")
                                                .font(.label(11))
                                        }
                                        .foregroundStyle(Color.ocPrimary)
                                    }
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .vanguardCard()
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
        .navigationTitle("使用量")
        .task {
            if let response = try? await gateway.sendRequest(method: "sessions.list", params: ["limit": 20, "includeLastMessage": true]),
               response.ok,
               let payload = response.payload?.dict,
               let sessions = payload["sessions"] as? [[String: Any]] {
                usageData = sessions
            }
        }
    }
}
