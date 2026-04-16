import Foundation
import Combine

@MainActor
final class ChatService: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isAgentTyping = false
    @Published var currentStreamText = ""
    @Published var hasLoadedHistory = false

    private let gateway: GatewayClient
    private(set) var sessionKey: String = "agent:main:main"
    private let model = "main"

    init(gateway: GatewayClient) {
        self.gateway = gateway
    }

    func resolveSession() async {
        do {
            let response = try await gateway.sendRequest(
                method: "sessions.list",
                params: ["limit": 30, "includeLastMessage": true]
            )
            if response.ok,
               let payload = response.payload?.dict,
               let sessions = payload["sessions"] as? [[String: Any]] {
                for session in sessions {
                    if let key = session["key"] as? String,
                       key.hasSuffix(":main"),
                       !key.contains("cron"),
                       !key.contains("subagent") {
                        sessionKey = key
                        break
                    }
                }
            }
        } catch {
            NSLog("[Chat] resolveSession failed: \(error.localizedDescription)")
        }
    }

    func loadHistory() async {
        guard !hasLoadedHistory else { return }

        await resolveSession()

        do {
            let response = try await gateway.sendRequest(
                method: "chat.history",
                params: [
                    "sessionKey": sessionKey,
                    "limit": 50,
                    "includeTools": false,
                ]
            )

            guard response.ok,
                  let payload = response.payload?.dict,
                  let history = payload["messages"] as? [[String: Any]] else {
                hasLoadedHistory = true
                return
            }

            var loaded: [ChatMessage] = []
            for msg in history {
                let roleStr = msg["role"] as? String ?? "system"
                guard roleStr == "user" || roleStr == "assistant" else { continue }

                let content = extractText(from: msg["content"])
                guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }

                let role: ChatMessage.Role = roleStr == "user" ? .user : .assistant
                loaded.append(ChatMessage(role: role, content: content))
            }

            messages = Array(loaded.suffix(20))
            hasLoadedHistory = true
        } catch {
            hasLoadedHistory = true
            NSLog("[Chat] loadHistory failed: \(error.localizedDescription)")
        }
    }

    func send(_ text: String) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        messages.append(ChatMessage(role: .user, content: trimmed))
        isAgentTyping = true
        currentStreamText = ""

        do {
            let stream = gateway.streamChat(message: trimmed, sessionKey: sessionKey, model: model)
            for try await delta in stream {
                currentStreamText += delta
            }
            finishAssistantMessage()
        } catch {
            isAgentTyping = false
            currentStreamText = ""
            messages.append(ChatMessage(role: .system, content: "发送失败: \(error.localizedDescription)"))
        }
    }

    private func finishAssistantMessage() {
        isAgentTyping = false
        let text = currentStreamText.trimmingCharacters(in: .whitespacesAndNewlines)
        currentStreamText = ""

        guard !text.isEmpty else { return }
        messages.append(ChatMessage(role: .assistant, content: text))
    }

    private func extractText(from rawContent: Any?) -> String {
        if let text = rawContent as? String {
            return text
        }

        if let blocks = rawContent as? [[String: Any]] {
            return blocks.compactMap { block in
                let type = block["type"] as? String
                if type == "text" || type == "output_text" {
                    return block["text"] as? String
                }
                return nil
            }
            .joined(separator: "\n")
        }

        return ""
    }
}
