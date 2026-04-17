import SwiftUI

struct NodesView: View {
    @EnvironmentObject var gateway: GatewayClient
    @State private var nodes: [NodeInfo] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var latestHint: String? {
        gateway.nodesErrorHint()
    }

    var body: some View {
        ZStack {
            Color.surfaceBase.ignoresSafeArea()
            BlueprintGrid()

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    SectionLabel(text: "已连接设备")
                    Text("节点")
                        .font(.headline(28))
                        .foregroundStyle(Color.textPrimary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                if isLoading && nodes.isEmpty {
                    Spacer()
                    HStack { Spacer(); ProgressView().tint(.ocPrimary); Spacer() }
                    Spacer()
                } else if nodes.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.textTertiary)
                        Text(errorMessage ?? "暂无可见 IronClaw 节点")
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
                            ForEach(nodes) { node in
                                NodeCard(node: node)
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
                Button { Task { await loadNodes() } } label: {
                    Image(systemName: "arrow.clockwise").foregroundStyle(Color.ocPrimary)
                }
            }
        }
        .task { await loadNodes() }
    }

    private func loadNodes() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            gateway.noteViewRequest("nodes_view", detail: "刷新节点列表（基于 sessions 映射）")
            let response = try await gateway.sendRequest(method: "sessions.list", params: ["limit": 100])
            guard response.ok,
                  let payload = response.payload?.dict,
                  let sessions = payload["sessions"] as? [[String: Any]] else {
                errorMessage = "节点列表返回了不可识别的数据"
                gateway.noteViewFailure("nodes_view", error: GatewayError.invalidResponse)
                return
            }

            nodes = sessions.compactMap { dict in
                guard let key = dict["key"] as? String else { return nil }
                let kind = dict["kind"] as? String ?? "direct"
                return NodeInfo(
                    deviceId: key,
                    host: dict["label"] as? String,
                    platform: "ironclaw",
                    version: dict["model"] as? String,
                    caps: [kind],
                    lastSeen: nil
                )
            }
            gateway.noteViewSuccess("nodes_view", detail: "节点数=\(nodes.count)")
        } catch {
            errorMessage = error.localizedDescription
            gateway.noteViewFailure("nodes_view", error: error)
        }
    }
}

struct NodeCard: View {
    let node: NodeInfo

    var body: some View {
        HStack(spacing: 14) {
            IconAvatar(icon: node.platformIcon, color: Color.ocPrimary, size: 44)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(node.displayName)
                        .font(.body(14, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    if let platform = node.platform {
                        KindBadge(text: platform)
                    }
                }

                if let version = node.version {
                    Text("v\(version)")
                        .font(.label(10))
                        .foregroundStyle(Color.textTertiary)
                }

                if let caps = node.caps, !caps.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(caps.prefix(4), id: \.self) { cap in
                            Text(cap.uppercased())
                                .font(.label(8, weight: .bold))
                                .tracking(0.5)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.surfaceContainerHighest)
                                .foregroundStyle(Color.textTertiary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(14)
        .vanguardCard()
    }
}
