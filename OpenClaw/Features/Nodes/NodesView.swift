import SwiftUI

struct NodesView: View {
    @EnvironmentObject var gateway: GatewayClient
    @State private var nodes: [NodeInfo] = []
    @State private var isLoading = false

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
                        Text("暂无配对设备")
                            .font(.label(11, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(Color.textTertiary)
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
        defer { isLoading = false }
        do {
            let response = try await gateway.sendRequest(method: "system-presence")
            guard response.ok,
                  let payload = response.payload?.dict,
                  let entries = payload["entries"] as? [[String: Any]] else { return }
            nodes = entries.compactMap { dict in
                guard let deviceId = dict["deviceId"] as? String else { return nil }
                return NodeInfo(
                    deviceId: deviceId, host: dict["host"] as? String,
                    platform: dict["platform"] as? String, version: dict["version"] as? String,
                    caps: dict["caps"] as? [String], lastSeen: nil
                )
            }
        } catch {}
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
