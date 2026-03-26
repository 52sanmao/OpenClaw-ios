import SwiftUI

/// Manages exec approval requests from the gateway.
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
                    id: requestId,
                    command: command,
                    workdir: dict["workdir"] as? String,
                    sessionKey: dict["sessionKey"] as? String,
                    timestamp: Date()
                )

                self?.pendingApprovals.append(request)
                Haptics.notification(.warning)
            }
        }
    }

    func approve(_ request: ApprovalRequest) async {
        _ = try? await gateway.sendRequest(
            method: "exec.approval.resolve",
            params: [
                "requestId": request.id,
                "approved": true
            ]
        )
        pendingApprovals.removeAll { $0.id == request.id }
        Haptics.notification(.success)
    }

    func reject(_ request: ApprovalRequest) async {
        _ = try? await gateway.sendRequest(
            method: "exec.approval.resolve",
            params: [
                "requestId": request.id,
                "approved": false
            ]
        )
        pendingApprovals.removeAll { $0.id == request.id }
    }
}

/// Banner shown at top of chat when exec approvals are pending.
struct ExecApprovalBanner: View {
    @ObservedObject var service: ExecApprovalService

    var body: some View {
        if let request = service.pendingApprovals.first {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "exclamationmark.shield.fill")
                        .foregroundStyle(.yellow)
                    Text("Approval Required")
                        .font(.subheadline.bold())
                    Spacer()
                    Text(request.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Command preview
                Text(request.command)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                if let workdir = request.workdir {
                    Text("in \(workdir)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Action buttons
                HStack(spacing: 12) {
                    Button {
                        Task { await service.reject(request) }
                    } label: {
                        Text("Reject")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray5))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Button {
                        Task { await service.approve(request) }
                    } label: {
                        Text("Approve")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.green)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

                if service.pendingApprovals.count > 1 {
                    Text("+\(service.pendingApprovals.count - 1) more pending")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
            .padding(.horizontal, 12)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
