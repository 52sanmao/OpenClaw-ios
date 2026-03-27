import SwiftUI

/// Live view of all active agent runs with real-time status.
struct LiveAgentsView: View {
    @EnvironmentObject var gateway: GatewayClient
    @StateObject private var viewModel = LiveAgentsViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Summary bar
                if !viewModel.agents.isEmpty {
                    SummaryBar(
                        active: viewModel.agents.filter { $0.isActive }.count,
                        total: viewModel.agents.count
                    )
                }

                Group {
                    if viewModel.isLoading && viewModel.agents.isEmpty {
                        ProgressView("Loading agents...")
                    } else if viewModel.agents.isEmpty {
                        ContentUnavailableView(
                            "No Agents",
                            systemImage: "bolt.slash",
                            description: Text("Active agent runs will appear here.")
                        )
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.agents) { agent in
                                    AgentCard(agent: agent)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    }
                }
            }
            .navigationTitle("Agents")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.refresh(gateway: gateway) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task {
                viewModel.startListening(gateway: gateway)
                await viewModel.refresh(gateway: gateway)
            }
        }
    }
}

// MARK: - Summary Bar

private struct SummaryBar: View {
    let active: Int
    let total: Int

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                Circle()
                    .fill(active > 0 ? Color.orange : Color.gray)
                    .frame(width: 8, height: 8)
                Text("\(active) active")
                    .font(.subheadline.bold())
                    .foregroundStyle(active > 0 ? .orange : .secondary)
            }

            Text("\(total - active) idle")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Agent Card

private struct AgentCard: View {
    let agent: AgentRun

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: name + status
            HStack {
                Text(agent.emoji ?? "")
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(agent.displayName)
                        .font(.headline)
                        .lineLimit(1)

                    if let title = agent.sessionTitle {
                        Text(title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                StatusBadge(status: agent.status)
            }

            // Model + elapsed
            HStack(spacing: 12) {
                if let model = agent.model {
                    Label(model, systemImage: "cpu")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let elapsed = agent.elapsedFormatted {
                    Label(elapsed, systemImage: "timer")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let kind = agent.kind {
                    Text(kind)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                }
            }

            // Latest output preview
            if let preview = agent.latestOutput, !preview.isEmpty {
                Text(preview)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(14)
        .background(Color(.systemGray6).opacity(agent.isActive ? 1 : 0.5))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    agent.isActive ? Color.orange.opacity(0.4) : Color.clear,
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .opacity(agent.isActive ? 1 : 0.6)
    }
}

// MARK: - Status Badge

private struct StatusBadge: View {
    let status: AgentRun.Status

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.caption2.bold())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }

    private var color: Color {
        switch status {
        case .thinking: .orange
        case .toolUse: .blue
        case .streaming: .green
        case .idle: .gray
        case .error: .red
        }
    }

    private var label: String {
        switch status {
        case .thinking: "Thinking"
        case .toolUse: "Tool Use"
        case .streaming: "Streaming"
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
