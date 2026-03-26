import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var gateway: GatewayClient

    var body: some View {
        NavigationStack {
            List {
                // Connection info
                Section("Connection") {
                    if let config = ConnectionStore.load() {
                        LabeledContent("Host", value: config.displayName)
                        LabeledContent("TLS", value: config.useTLS ? "Enabled" : "Disabled")
                    }
                    LabeledContent("Status", value: statusText)
                    if !gateway.serverVersion.isEmpty {
                        LabeledContent("Server Version", value: gateway.serverVersion)
                    }
                    if !gateway.serverHost.isEmpty {
                        LabeledContent("Server Host", value: gateway.serverHost)
                    }
                }

                // Diagnostics
                Section("Diagnostics") {
                    NavigationLink {
                        HealthView()
                    } label: {
                        Label("Health & Channels", systemImage: "heart.text.square.fill")
                    }
                }

                // Actions
                Section("Actions") {
                    Button(role: .destructive) {
                        gateway.disconnect()
                        ConnectionStore.clear()
                    } label: {
                        Label("Disconnect", systemImage: "wifi.slash")
                    }
                }

                // About
                Section("About") {
                    LabeledContent("App Version", value: "0.1.0")
                    Link(destination: URL(string: "https://docs.openclaw.ai")!) {
                        Label("Documentation", systemImage: "book.fill")
                    }
                    Link(destination: URL(string: "https://github.com/openclaw/openclaw")!) {
                        Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                    Link(destination: URL(string: "https://discord.com/invite/clawd")!) {
                        Label("Discord", systemImage: "bubble.left.and.text.bubble.right.fill")
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }

    private var statusText: String {
        switch gateway.connectionState {
        case .connected: "Connected"
        case .connecting: "Connecting..."
        case .disconnected: "Disconnected"
        case .error(let msg): "Error: \(msg)"
        }
    }
}
