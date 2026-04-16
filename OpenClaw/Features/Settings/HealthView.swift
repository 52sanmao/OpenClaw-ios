import SwiftUI
import UIKit

struct HealthView: View {
    @EnvironmentObject var gateway: GatewayClient
    @State private var sessionCount = 0
    @State private var isLoading = false
    @State private var healthError: String?

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

                    if let healthError {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel(text: "错误")
                            Text(healthError)
                                .font(.body(12))
                                .foregroundStyle(Color.ocError)
                            Text("如果这里只有统计或 routines 失败，而聊天页仍能对话，问题通常在扩展接口而不是聊天主链路。")
                                .font(.label(10))
                                .foregroundStyle(Color.textTertiary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel(text: "调试日志")

                        VStack(alignment: .leading, spacing: 8) {
                            if gateway.debugLog.isEmpty {
                                Text("尚无调试日志")
                                    .font(.body(12))
                                    .foregroundStyle(Color.textTertiary)
                            } else {
                                ForEach(Array(gateway.debugLog.suffix(8).enumerated()), id: \.offset) { _, entry in
                                    Text(entry)
                                        .font(.body(11))
                                        .foregroundStyle(Color.textSecondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }

                            HStack(spacing: 12) {
                                Button("复制日志") {
                                    UIPasteboard.general.string = gateway.debugLogExportText
                                }
                                .font(.label(10, weight: .bold))
                                .tracking(1.5)
                                .foregroundStyle(Color.ocPrimary)

                                Button("清空日志") {
                                    gateway.clearDebugLog()
                                }
                                .font(.label(10, weight: .bold))
                                .tracking(1.5)
                                .foregroundStyle(Color.textTertiary)
                            }
                        }
                        .padding(14)
                        .vanguardCard()
                    }

                    Text("健康页显示的是主 HTTP 链路与最近请求日志，用来区分聊天主路径故障和扩展接口故障。")
                        .font(.label(10))
                        .foregroundStyle(Color.textTertiary)

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
        healthError = nil
        defer { isLoading = false }
        do {
            let response = try await gateway.sendRequest(method: "sessions.list", params: ["limit": 100])
            guard response.ok,
                  let payload = response.payload?.dict,
                  let sessions = payload["sessions"] as? [[String: Any]] else {
                healthError = "会话列表返回了不可识别的数据"
                return
            }
            sessionCount = sessions.count
        } catch {
            healthError = error.localizedDescription
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
