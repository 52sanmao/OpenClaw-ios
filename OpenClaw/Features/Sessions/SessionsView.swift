import SwiftUI

struct SessionsView: View {
    @EnvironmentObject var gateway: GatewayClient
    @State private var sessions: [SessionInfo] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var latestHint: String? {
        gateway.sessionsErrorHint()
    }

    var body: some View {
        ZStack {
            Color.surfaceBase.ignoresSafeArea()
            BlueprintGrid()

            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    SectionLabel(text: "活跃协议")
                    Text("会话")
                        .font(.headline(28))
                        .foregroundStyle(Color.textPrimary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                if isLoading && sessions.isEmpty {
                    Spacer()
                    HStack { Spacer(); ProgressView().tint(.ocPrimary); Spacer() }
                    Spacer()
                } else if sessions.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "list.bullet.rectangle.portrait")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.textTertiary)
                        Text(errorMessage ?? "暂无活跃会话")
                            .font(.label(11, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(errorMessage == nil ? Color.textTertiary : Color.ocError)
                        if let latestHint {
                            Text(latestHint)
                                .font(.body(11))
                                .foregroundStyle(Color.textTertiary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(sessions) { session in
                                SessionCard(session: session)
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
                Button { Task { await loadSessions() } } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(Color.ocPrimary)
                }
            }
        }
        .task { await loadSessions() }
    }

    private func loadSessions() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            gateway.noteViewRequest("sessions_view", detail: "刷新会话列表")
            let response = try await gateway.sendRequest(
                method: "sessions.list",
                params: ["limit": 50, "includeDerivedTitles": true, "includeLastMessage": true]
            )
            guard response.ok,
                  let payload = response.payload?.dict,
                  let arr = payload["sessions"] as? [[String: Any]] else {
                errorMessage = "会话列表返回了不可识别的数据"
                gateway.noteViewFailure("sessions_view", error: GatewayError.invalidResponse)
                return
            }
            sessions = arr.compactMap { dict in
                guard let key = dict["key"] as? String else { return nil }
                return SessionInfo(
                    key: key, agentId: dict["agentId"] as? String,
                    label: dict["label"] as? String, lastActive: nil,
                    derivedTitle: dict["derivedTitle"] as? String,
                    lastMessage: dict["lastMessage"] as? String,
                    kind: dict["kind"] as? String
                )
            }
            gateway.noteViewSuccess("sessions_view", detail: "会话数=\(sessions.count)")
        } catch {
            errorMessage = error.localizedDescription
            gateway.noteViewFailure("sessions_view", error: error)
        }
    }
}

struct SessionCard: View {
    let session: SessionInfo

    var body: some View {
        HStack(spacing: 14) {
            IconAvatar(icon: iconForKind, color: colorForKind, size: 44)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(session.displayTitle)
                        .font(.body(14, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    if let kind = session.kind {
                        KindBadge(text: kind, color: colorForKind)
                    }
                }
                if let msg = session.lastMessage {
                    Text(msg)
                        .font(.body(12))
                        .foregroundStyle(Color.textTertiary)
                        .lineLimit(2)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(Color.textTertiary)
        }
        .padding(14)
        .vanguardCard()
    }

    private var iconForKind: String {
        switch session.kind {
        case "cron": "clock.fill"
        case "subagent": "arrow.triangle.branch"
        default: "bubble.left.fill"
        }
    }

    private var colorForKind: Color {
        switch session.kind {
        case "cron": Color.ocTertiary
        case "subagent": Color.textTertiary
        default: Color.ocPrimary
        }
    }
}
