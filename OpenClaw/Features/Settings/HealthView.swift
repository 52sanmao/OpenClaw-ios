import SwiftUI

struct HealthView: View {
    @EnvironmentObject var gateway: GatewayClient
    @State private var healthData: [String: Any] = [:]
    @State private var channelStatuses: [[String: Any]] = []
    @State private var isLoading = false

    var body: some View {
        List {
            Section("Gateway") {
                LabeledContent("Version", value: gateway.serverVersion)
                LabeledContent("Host", value: gateway.serverHost)
                LabeledContent("Status") {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Running")
                    }
                }
            }

            if !channelStatuses.isEmpty {
                Section("Channels") {
                    ForEach(Array(channelStatuses.enumerated()), id: \.offset) { _, channel in
                        let name = channel["channel"] as? String ?? "Unknown"
                        let status = channel["status"] as? String ?? "unknown"
                        let connected = status == "connected" || status == "ready"

                        HStack {
                            Image(systemName: channelIcon(name))
                                .foregroundStyle(connected ? .green : .red)
                            Text(name.capitalized)
                            Spacer()
                            Text(status)
                                .font(.caption)
                                .foregroundStyle(connected ? .green : .red)
                        }
                    }
                }
            }

            Section("Usage") {
                NavigationLink("Session Usage") {
                    UsageView()
                }
            }
        }
        .navigationTitle("Health")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await loadHealth() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task { await loadHealth() }
    }

    private func loadHealth() async {
        isLoading = true
        defer { isLoading = false }

        // Fetch health
        if let response = try? await gateway.sendRequest(method: "health"),
           response.ok,
           let payload = response.payload?.dict {
            healthData = payload
        }

        // Fetch channel status
        if let response = try? await gateway.sendRequest(method: "channels.status"),
           response.ok,
           let payload = response.payload?.dict,
           let channels = payload["channels"] as? [[String: Any]] {
            channelStatuses = channels
        }
    }

    private func channelIcon(_ name: String) -> String {
        switch name.lowercased() {
        case "telegram": return "paperplane.fill"
        case "whatsapp": return "phone.fill"
        case "discord": return "gamecontroller.fill"
        case "slack": return "number"
        case "signal": return "lock.fill"
        default: return "bubble.fill"
        }
    }
}

struct UsageView: View {
    @EnvironmentObject var gateway: GatewayClient
    @State private var usageData: [[String: Any]] = []

    var body: some View {
        List {
            if usageData.isEmpty {
                ContentUnavailableView(
                    "No Usage Data",
                    systemImage: "chart.bar",
                    description: Text("Session usage will appear here.")
                )
            } else {
                ForEach(Array(usageData.enumerated()), id: \.offset) { _, session in
                    let key = session["key"] as? String ?? "Unknown"
                    let inputTokens = session["inputTokens"] as? Int ?? 0
                    let outputTokens = session["outputTokens"] as? Int ?? 0

                    VStack(alignment: .leading, spacing: 4) {
                        Text(key)
                            .font(.headline)
                            .lineLimit(1)
                        HStack(spacing: 16) {
                            Label("\(inputTokens)", systemImage: "arrow.right")
                            Label("\(outputTokens)", systemImage: "arrow.left")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Usage")
        .task {
            if let response = try? await gateway.sendRequest(
                method: "sessions.usage",
                params: ["limit": 20]
            ),
               response.ok,
               let payload = response.payload?.dict,
               let sessions = payload["sessions"] as? [[String: Any]] {
                usageData = sessions
            }
        }
    }
}
