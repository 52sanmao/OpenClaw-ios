import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var gateway: GatewayClient
    @EnvironmentObject var notifications: NotificationService

    var body: some View {
        ZStack {
            Color.surfaceBase.ignoresSafeArea()
            BlueprintGrid()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        SectionLabel(text: "配置")
                        Text("设置")
                            .font(.headline(28))
                            .foregroundStyle(Color.textPrimary)
                    }
                    .padding(.top, 16)

                    // Notifications
                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel(text: "通知")

                        HStack {
                            Image(systemName: "bell.fill")
                                .foregroundStyle(Color.ocPrimary)
                            Text("推送通知")
                                .font(.body(14, weight: .medium))
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                            if notifications.isAuthorized {
                                HStack(spacing: 4) {
                                    StatusLED(color: Color.ocSuccess)
                                    Text("已启用")
                                        .font(.label(9, weight: .bold))
                                        .tracking(1)
                                        .foregroundStyle(Color.ocSuccess)
                                }
                            } else {
                                Button {
                                    notifications.requestPermission()
                                } label: {
                                    Text("启用")
                                        .font(.label(10, weight: .bold))
                                        .tracking(1)
                                        .foregroundStyle(Color.ocPrimary)
                                }
                            }
                        }
                        .padding(14)
                        .vanguardCard()
                    }

                    // Connection
                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel(text: "网关连接")

                        VStack(spacing: 0) {
                            if let config = ConnectionStore.load() {
                                SettingsRow(label: "主机", value: config.displayName)
                                SettingsRow(label: "TLS", value: config.useTLS ? "已启用" : "已禁用")
                            }
                            SettingsRow(label: "状态", value: statusText, valueColor: statusColor)
                            if !gateway.serverVersion.isEmpty {
                                SettingsRow(label: "版本", value: gateway.serverVersion)
                            }
                            if !gateway.serverHost.isEmpty {
                                SettingsRow(label: "服务器", value: gateway.serverHost)
                            }
                        }
                        .vanguardCard()
                    }

                    // Diagnostics
                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel(text: "诊断")

                        NavigationLink {
                            HealthView()
                        } label: {
                            HStack {
                                Image(systemName: "heart.text.square.fill")
                                    .foregroundStyle(Color.ocPrimary)
                                Text("健康与频道")
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

                    // Disconnect
                    Button(role: .destructive) {
                        gateway.disconnect()
                        ConnectionStore.clear()
                    } label: {
                        HStack {
                            Image(systemName: "wifi.slash")
                            Text("断开连接")
                                .font(.label(12, weight: .bold))
                                .tracking(1.5)
                        }
                        .foregroundStyle(Color.ocError)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.ocError.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .strokeBorder(Color.ocError.opacity(0.2), lineWidth: 1)
                        )
                    }

                    // About
                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel(text: "关于")

                        VStack(spacing: 0) {
                            SettingsRow(label: "应用", value: "开放爪 iOS v0.2.0")
                            SettingsRow(label: "文档", value: "docs.openclaw.ai", isLink: true)
                            SettingsRow(label: "源码", value: "github.com/openclaw", isLink: true)
                        }
                        .vanguardCard()
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
            }
        }
        .navigationTitle("")
    }

    private var statusText: String {
        switch gateway.connectionState {
        case .connected: "已连接"
        case .connecting: "连接中..."
        case .disconnected: "已断开"
        case .error(let msg): msg
        }
    }

    private var statusColor: Color {
        switch gateway.connectionState {
        case .connected: Color.ocSuccess
        case .connecting: Color.ocTertiary
        default: Color.ocError
        }
    }
}

struct SettingsRow: View {
    let label: String
    let value: String
    var valueColor: Color = .textSecondary
    var isLink: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(.label(10, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(Color.textTertiary)
            Spacer()
            Text(value)
                .font(.body(13))
                .foregroundStyle(isLink ? Color.ocPrimary : valueColor)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}
