import SwiftUI

/// Live view of all active agent runs with real-time status.
struct LiveAgentsView: View {
    @EnvironmentObject var gateway: GatewayClient
    @StateObject private var viewModel = LiveAgentsViewModel()

    var body: some View {
        ZStack {
            Color.surfaceBase.ignoresSafeArea()
            BlueprintGrid()

            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        SectionLabel(text: "实时监控")
                        Text("代理")
                            .font(.headline(28))
                            .foregroundStyle(Color.textPrimary)
                    }
                    Spacer()
                    if !viewModel.agents.isEmpty {
                        let active = viewModel.agents.filter { $0.isActive }.count
                        HStack(spacing: 8) {
                            HStack(spacing: 4) {
                                StatusLED(color: active > 0 ? Color.ocPrimary : Color.textTertiary, pulsing: active > 0)
                                Text("\(active) 活跃")
                                    .font(.label(9, weight: .bold))
                                    .tracking(1)
                                    .foregroundStyle(active > 0 ? Color.ocPrimary : Color.textTertiary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                if viewModel.isLoading && viewModel.agents.isEmpty {
                    Spacer()
                    HStack { Spacer(); ProgressView().tint(.ocPrimary); Spacer() }
                    Spacer()
                } else if viewModel.agents.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "bolt.slash")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.textTertiary)
                        Text("暂无活跃代理")
                            .font(.label(11, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(Color.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.agents) { agent in
                                AgentCard(agent: agent)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.refresh(gateway: gateway) }
                } label: {
                    Image(systemName: "arrow.clockwise").foregroundStyle(Color.ocPrimary)
                }
            }
        }
        .task {
            viewModel.startListening(gateway: gateway)
            await viewModel.refresh(gateway: gateway)
        }
    }
}

// MARK: - Agent Card

private struct AgentCard: View {
    let agent: AgentRun

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if let emoji = agent.emoji {
                    Text(emoji)
                        .font(.title3)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(agent.displayName)
                        .font(.body(14, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)

                    if let title = agent.sessionTitle {
                        Text(title)
                            .font(.body(11))
                            .foregroundStyle(Color.textTertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                StatusBadge(status: agent.status)
            }

            HStack(spacing: 10) {
                if let model = agent.model {
                    HStack(spacing: 3) {
                        Image(systemName: "cpu")
                            .font(.system(size: 9))
                        Text(model)
                            .font(.label(9))
                    }
                    .foregroundStyle(Color.textTertiary)
                    .lineLimit(1)
                }

                if let elapsed = agent.elapsedFormatted {
                    HStack(spacing: 3) {
                        Image(systemName: "timer")
                            .font(.system(size: 9))
                        Text(elapsed)
                            .font(.label(9))
                    }
                    .foregroundStyle(Color.textTertiary)
                }

                if let kind = agent.kind {
                    KindBadge(text: kind)
                }
            }

            if let preview = agent.latestOutput, !preview.isEmpty {
                Text(preview)
                    .font(.body(11))
                    .foregroundStyle(Color.textTertiary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.surfaceContainer)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(14)
        .vanguardCard(glow: agent.isActive)
        .opacity(agent.isActive ? 1 : 0.5)
    }
}

// MARK: - Status Badge

private struct StatusBadge: View {
    let status: AgentRun.Status

    var body: some View {
        HStack(spacing: 4) {
            StatusLED(color: color, pulsing: status != .idle)
            Text(label.uppercased())
                .font(.label(8, weight: .bold))
                .tracking(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundStyle(color)
        .background(color.opacity(0.1))
        .overlay(Capsule().strokeBorder(color.opacity(0.2), lineWidth: 1))
        .clipShape(Capsule())
    }

    private var color: Color {
        switch status {
        case .thinking: Color.ocPrimary
        case .toolUse: Color.ocTertiary
        case .streaming: Color.ocSuccess
        case .idle: Color.textTertiary
        case .error: Color.ocError
        }
    }

    private var label: String {
        switch status {
        case .thinking: "思考中"
        case .toolUse: "工具使用"
        case .streaming: "流式传输"
        case .idle: "空闲"
        case .error: "错误"
        }
    }
}

// MARK: - Model

struct AgentRun: Identifiable {
    let id: String // sessionKey
    let agentId: String
    let displayName: String
    let emoji: String?
    let sessionTitle: String?
    let status: Status
    let model: String?
    let kind: String?
    let latestOutput: String?
    let startedAt: Date?

    var isActive: Bool {
        status != .idle
    }

    var elapsedFormatted: String? {
        guard let startedAt else { return nil }
        let elapsed = Date().timeIntervalSince(startedAt)
        if elapsed < 60 { return "\(Int(elapsed))s" }
        if elapsed < 3600 { return "\(Int(elapsed / 60))m" }
        return "\(Int(elapsed / 3600))h"
    }

    enum Status {
        case thinking, toolUse, streaming, idle, error
    }
}

// MARK: - ViewModel

@MainActor
final class LiveAgentsViewModel: ObservableObject {
    @Published var agents: [AgentRun] = []
    @Published var isLoading = false

    private var listeningSetup = false

    func startListening(gateway: GatewayClient) {
        guard !listeningSetup else { return }
        listeningSetup = true
    }

    private func inferDisplayName(agentId: String) -> String {
        agentId == "main" ? "IronClaw 主代理" : agentId
    }

    private func inferEmoji(agentId: String) -> String? {
        agentId == "main" ? "🤖" : nil
    }

    private func inferStatus(from kind: String?) -> AgentRun.Status {
        switch kind {
        case "cron": .toolUse
        case "subagent": .thinking
        default: .idle
        }
    }

    private func parseAgentId(from sessionKey: String) -> String {
        let parts = sessionKey.split(separator: ":")
        return parts.count > 1 ? String(parts[1]) : "main"
    }

    private func parseStartedAt(from session: [String: Any]) -> Date? {
        if let startedAt = session["startedAt"] as? Int {
            return Date(timeIntervalSince1970: Double(startedAt) / 1000)
        }
        if let updatedAt = session["updatedAt"] as? Int {
            return Date(timeIntervalSince1970: Double(updatedAt) / 1000)
        }
        return nil
    }

    private func extractLatestOutput(from session: [String: Any]) -> String? {
        (session["lastMessage"] as? String) ?? (session["label"] as? String)
    }

    private func extractSessionTitle(from session: [String: Any]) -> String? {
        (session["derivedTitle"] as? String) ?? (session["label"] as? String)
    }

    func refresh(gateway: GatewayClient) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let sessResponse = try await gateway.sendRequest(
                method: "sessions.list",
                params: [
                    "limit": 50,
                    "includeDerivedTitles": true,
                    "includeLastMessage": true,
                ]
            )

            guard sessResponse.ok,
                  let payload = sessResponse.payload?.dict,
                  let sessions = payload["sessions"] as? [[String: Any]] else { return }

            var runs: [AgentRun] = []

            for session in sessions {
                guard let key = session["key"] as? String else { continue }

                let agentId = parseAgentId(from: key)
                let kind = session["kind"] as? String ?? "direct"
                let model = session["model"] as? String

                runs.append(AgentRun(
                    id: key,
                    agentId: agentId,
                    displayName: inferDisplayName(agentId: agentId),
                    emoji: inferEmoji(agentId: agentId),
                    sessionTitle: extractSessionTitle(from: session),
                    status: inferStatus(from: kind),
                    model: model,
                    kind: kind,
                    latestOutput: extractLatestOutput(from: session),
                    startedAt: parseStartedAt(from: session)
                ))
            }

            agents = runs.sorted { a, b in
                if a.isActive != b.isActive { return a.isActive }
                return a.displayName < b.displayName
            }
        } catch {
            NSLog("[Agents] refresh failed: \(error)")
        }
    }
}
