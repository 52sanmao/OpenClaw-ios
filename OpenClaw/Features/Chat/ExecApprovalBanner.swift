import SwiftUI

/// Manages exec approval requests from the IronClaw service.
@MainActor
final class ExecApprovalService: ObservableObject {
    struct ApprovalRequest: Identifiable {
        let id: String
        let command: String
        let workdir: String?
        let sessionKey: String?
        let timestamp: Date
    }

    @Published var pendingApprovals: [ApprovalRequest] = []
    private let gateway: GatewayClient

    init(gateway: GatewayClient) {
        self.gateway = gateway
        setupListener()
    }

    private func setupListener() {
        gateway.onEvent("exec.approval.requested") { [weak self] payload in
            Task { @MainActor in
                guard let dict = payload?.dict,
                      let requestId = dict["requestId"] as? String,
                      let command = dict["command"] as? String else { return }
                let request = ApprovalRequest(
                    id: requestId, command: command,
                    workdir: dict["workdir"] as? String,
                    sessionKey: dict["sessionKey"] as? String,
                    timestamp: Date()
                )
                self?.pendingApprovals.append(request)
                Haptics.notification(.warning)
            }
        }
    }

    func approve(_ request: ApprovalRequest) async {}

    func reject(_ request: ApprovalRequest) async {}
}

/// Banner shown at top of chat when exec approvals are pending.
struct ExecApprovalBanner: View {
    @ObservedObject var service: ExecApprovalService

    var body: some View {
        if let request = service.pendingApprovals.first {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "exclamationmark.shield.fill")
                        .foregroundStyle(Color.ocTertiary)
                    Text("需要审批")
                        .font(.label(10, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(Color.ocTertiary)
                    Spacer()
                    Text(request.timestamp, style: .time)
                        .font(.label(9))
                        .foregroundStyle(Color.textTertiary)
                }

                // Command preview
                Text(request.command)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.surfaceContainerLow)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                if let workdir = request.workdir {
                    Text("in \(workdir)")
                        .font(.label(10))
                        .foregroundStyle(Color.textTertiary)
                }

                Text("IronClaw 当前未提供可用的移动端审批提交接口，请在服务端完成本次审批。")
                    .font(.label(10))
                    .foregroundStyle(Color.textTertiary)

                // Read-only until IronClaw supports approval resolution on this path
                HStack(spacing: 10) {
                    Text("请在服务端处理")
                        .font(.label(11, weight: .bold))
                        .tracking(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.surfaceContainerHigh)
                        .foregroundStyle(Color.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                if service.pendingApprovals.count > 1 {
                    Text("+\(service.pendingApprovals.count - 1) 个待处理")
                        .font(.label(9))
                        .foregroundStyle(Color.textTertiary)
                }
            }
            .padding(14)
            .background(Color.surfaceContainer)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color.ocTertiary.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, 12)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
