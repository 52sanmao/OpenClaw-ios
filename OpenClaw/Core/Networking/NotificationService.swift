import Foundation
import UserNotifications
import UIKit

/// Handles local push notifications for agent messages and exec approvals.
/// Supports inline reply directly from the notification banner.
@MainActor
final class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()

    // MARK: - Categories & Actions
    static let messageCategory = "AGENT_MESSAGE"
    static let approvalCategory = "EXEC_APPROVAL"
    static let replyAction = "REPLY_ACTION"
    static let approveAction = "APPROVE_ACTION"
    static let rejectAction = "REJECT_ACTION"

    @Published var isAuthorized = false

    private var gateway: GatewayClient { GatewayClient.shared }
    private var isAppActive = true

    private override init() {
        super.init()
    }

    // MARK: - Setup

    func configure() {
        registerCategories()
        requestPermission()
        observeAppState()
        listenForEvents()
    }

    private func registerCategories() {
        // Reply action (text input from notification)
        let replyAction = UNTextInputNotificationAction(
            identifier: Self.replyAction,
            title: "回复",
            options: [],
            textInputButtonTitle: "发送",
            textInputPlaceholder: "输入回复..."
        )

        // Message category with reply
        let messageCategory = UNNotificationCategory(
            identifier: Self.messageCategory,
            actions: [replyAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        // Approval category (read-only notice until IronClaw exposes resolve support)
        let approvalCategory = UNNotificationCategory(
            identifier: Self.approvalCategory,
            actions: [],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            messageCategory,
            approvalCategory,
        ])
    }

    func requestPermission() {
        Task {
            do {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                    options: [.alert, .sound, .badge]
                )
                self.isAuthorized = granted
            } catch {
                self.isAuthorized = false
            }
        }
    }

    // MARK: - App State

    private func observeAppState() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.isAppActive = true }
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.isAppActive = false }
        }
    }

    // MARK: - Event Listeners

    private func listenForEvents() {
        // Agent done (full message ready)
        gateway.onEvent("agent.done") { [weak self] payload in
            Task { @MainActor in
                guard let self, !self.isAppActive else { return }

                let dict = payload?.dict
                let text = dict?["text"] as? String
                    ?? dict?["message"] as? String
                    ?? "代理发来新消息"
                let sessionKey = dict?["sessionKey"] as? String

                self.showMessageNotification(text: text, sessionKey: sessionKey)
            }
        }

        // Exec approval requested
        gateway.onEvent("exec.approval.requested") { [weak self] payload in
            Task { @MainActor in
                guard let self else { return }

                let dict = payload?.dict
                let requestId = dict?["requestId"] as? String ?? ""
                let command = dict?["command"] as? String ?? "未知命令"

                self.showApprovalNotification(requestId: requestId, command: command)
            }
        }
    }

    // MARK: - Show Notifications

    private func showMessageNotification(text: String, sessionKey: String?) {
        let content = UNMutableNotificationContent()
        content.title = "IronClaw"
        content.body = String(text.prefix(256))
        content.sound = .default
        content.categoryIdentifier = Self.messageCategory
        if let sessionKey {
            content.userInfo["sessionKey"] = sessionKey
        }

        let request = UNNotificationRequest(
            identifier: "agent-msg-\(UUID().uuidString)",
            content: content,
            trigger: nil // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func showApprovalNotification(requestId: String, command: String) {
        let content = UNMutableNotificationContent()
        content.title = "需要审批"
        content.body = "IronClaw 当前未开放移动端审批处理，请回到服务端确认：\(command.prefix(160))"
        content.sound = .default
        content.categoryIdentifier = Self.approvalCategory
        content.userInfo["requestId"] = requestId
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(
            identifier: "approval-\(requestId)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Handle Notification Responses

    func handleNotificationResponse(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo
        let categoryId = response.notification.request.content.categoryIdentifier

        switch (categoryId, response.actionIdentifier) {

        // Reply to agent message
        case (Self.messageCategory, Self.replyAction):
            if let textResponse = response as? UNTextInputNotificationResponse {
                let replyText = textResponse.userText
                let sessionKey = userInfo["sessionKey"] as? String
                Task {
                    if let sessionKey {
                        let stream = gateway.streamChat(message: replyText, sessionKey: sessionKey)
                        for try await _ in stream {}
                    }
                }
            }

        default:
            break
        }
    }
}
