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
                        SectionLabel(text: "Live Monitoring")
                        Text("Agents")
                            .font(.headline(28))
                            .foregroundStyle(Color.textPrimary)
                    }
                    Spacer()
                    if !viewModel.agents.isEmpty {
                        let active = viewModel.agents.filter { $0.isActive }.count
                        HStack(spacing: 8) {
                            HStack(spacing: 4) {
                                StatusLED(color: active > 0 ? Color.ocPrimary : Color.textTertiary, pulsing: active > 0)
                                Text("\(active) ACTIVE")
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
                        Text("NO ACTIVE AGENTS")
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
        case .thinking: "Thinking"
        case .toolUse: "Tool Use"
        case .streaming: "Stream"
        case .idle: "Idle"
        case .error: "Error"
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

        // Listen for chat events to update status in real-time
        gateway.onEvent("chat") { [weak self] payload in
            Task { @MainActor in
                guard let self,
                      let dict = payload?.dict,
                      let sessionKey = dict["sessionKey"] as? String,
                      let state = dict["state"] as? String else { return }

                if let idx = self.agents.firstIndex(where: { $0.id == sessionKey }) {
                    var agent = self.agents[idx]
                    let newStatus: AgentRun.Status = switch state {
                    case "delta": .streaming
                    case "final": .idle
                    case "error": .error
                    default: agent.status
                    }

                    self.agents[idx] = AgentRun(
                        id: agent.id,
                        agentId: agent.agentId,
                        displayName: agent.displayName,
                        emoji: agent.emoji,
                        sessionTitle: agent.sessionTitle,
                        status: newStatus,
                        model: agent.model,
                        kind: agent.kind,
                        latestOutput: agent.latestOutput,
                        startedAt: agent.startedAt
                    )
                }
            }
        }
    }

    func refresh(gateway: GatewayClient) async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Get sessions
            let sessResponse = try await gateway.sendRequest(
                method: "sessions.list",
                params: [
                    "limit": 50,
                    "includeDerivedTitles": true,
                    "includeLastMessage": true
                ]
            )

            guard sessResponse.ok,
                  let payload = sessResponse.payload?.dict,
                  let sessions = payload["sessions"] as? [[String: Any]] else { return }

            // Get agent identities
            var identities: [String: (name: String, emoji: String?)] = [:]
            let idResponse = try? await gateway.sendRequest(method: "agent.identity", params: [:])
            if let idPayload = idResponse?.payload?.dict {
                let name = idPayload["name"] as? String ?? "main"
                let emoji = idPayload["emoji"] as? String
                identities["main"] = (name, emoji)
            }

            var runs: [AgentRun] = []

            for sess in sessions {
                guard let key = sess["key"] as? String else { continue }

                // Skip cron sessions older than 1 hour
                let kind = sess["kind"] as? String ?? "direct"

                // Parse agent ID from session key (format: agent:<agentId>:<rest>)
                let parts = key.split(separator: ":")
                let agentId = parts.count > 1 ? String(parts[1]) : "main"

                let identity = identities[agentId]
                let title = sess["derivedTitle"] as? String
                let lastMessage = sess["lastMessage"] as? String
                let model = sess["model"] as? String

                runs.append(AgentRun(
                    id: key,
                    agentId: agentId,
                    displayName: identity?.name ?? agentId,
                    emoji: identity?.emoji,
                    sessionTitle: title,
                    status: .idle,
                    model: model,
                    kind: kind,
                    latestOutput: lastMessage,
                    startedAt: nil
                ))
            }

            // Sort: active first, then by name
            agents = runs.sorted { a, b in
                if a.isActive != b.isActive { return a.isActive }
                return a.displayName < b.displayName
            }
        } catch {
            NSLog("[Agents] refresh failed: \(error)")
        }
    }
}
