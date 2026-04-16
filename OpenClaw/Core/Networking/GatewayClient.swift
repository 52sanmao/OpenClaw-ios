import Foundation
import Combine

@MainActor
final class GatewayClient: ObservableObject {
    static let shared = GatewayClient()

    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
        case error(String)
    }

    @Published var connectionState: ConnectionState = .disconnected
    @Published var serverVersion: String = ""
    @Published var serverHost: String = ""
    @Published var connId: String = ""
    @Published var uptimeMs: Int = 0
    @Published var debugLog: [String] = []

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var eventHandlers: [String: [(AnyCodable?) -> Void]] = [:]
    private var threadIDsBySessionKey: [String: String] = [:]
    private let debugLogLimit = 200

    private func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry = "[\(timestamp)] \(message)"
        debugLog.append(entry)
        if debugLog.count > debugLogLimit {
            debugLog.removeFirst(debugLog.count - debugLogLimit)
        }
    }

    var debugLogExportText: String {
        let lines = [
            "IronClaw 主机: \(serverHost.isEmpty ? "未连接" : serverHost)",
            "版本: \(serverVersion.isEmpty ? "未知" : serverVersion)",
            "连接状态: \(String(describing: connectionState))",
            "聊天链路: /api/chat/thread/new -> /api/chat/send -> /api/chat/history",
            "",
            "调试日志:",
        ] + debugLog
        return lines.joined(separator: "\n")
    }

    func clearDebugLog() {
        debugLog.removeAll()
    }

    private var config: ConnectionConfig? {
        ConnectionStore.load()
    }

    private init() {}

    func connect(config: ConnectionConfig? = nil) async throws {
        let cfg = config ?? self.config
        guard let cfg else {
            throw GatewayError.noConfig
        }

        connectionState = .connecting
        ConnectionStore.save(cfg)
        log("开始连接 \(cfg.httpBaseURL.absoluteString)")

        do {
            let models = try await fetchModels(config: cfg)
            serverVersion = models.data?.first?.id ?? "IronClaw"
            serverHost = cfg.httpBaseURL.host ?? cfg.displayName
            connId = ""
            uptimeMs = 0
            await mappedConnectionMetadata(config: cfg)
            log("模型探活成功，已连接到 \(serverHost)")
            connectionState = .connected
        } catch {
            clearServerInfo()
            log("连接失败: \(error.localizedDescription)")
            connectionState = .error(error.localizedDescription)
            throw error
        }
    }

    func disconnect() {
        log("手动断开连接")
        clearServerInfo()
        threadIDsBySessionKey.removeAll()
        connectionState = .disconnected
    }

    @discardableResult
    func sendRequest(method: String, params: [String: Any]? = nil) async throws -> ResponseFrame {
        guard connectionState == .connected || config != nil else {
            throw GatewayError.notConnected
        }

        log("请求 \(method)")

        switch method {
        case "ping":
            return ResponseFrame(type: "res", id: UUID().uuidString, ok: true, payload: AnyCodable(["ok": true]), error: nil)

        case "sessions.list":
            let limit = params?["limit"] as? Int ?? 50
            return try await mappedSessionsListResponse(limit: limit)

        case "chat.history":
            guard let sessionKey = params?["sessionKey"] as? String else {
                throw GatewayError.invalidResponse
            }
            let limit = params?["limit"] as? Int ?? 50
            let includeTools = params?["includeTools"] as? Bool ?? false
            return try await mappedChatHistoryResponse(sessionKey: sessionKey, limit: limit, includeTools: includeTools)

        case "cron.list":
            let includeDisabled = params?["includeDisabled"] as? Bool ?? true
            let routines = try await fetchRoutines(includeDisabled: includeDisabled)
            let payload: [String: Any] = [
                "jobs": routines.map(Self.cronJobPayload(from:))
            ]
            return ResponseFrame(type: "res", id: UUID().uuidString, ok: true, payload: AnyCodable(payload), error: nil)

        case "cron.update":
            guard let jobId = params?["jobId"] as? String,
                  let patch = params?["patch"] as? [String: Any] else {
                throw GatewayError.invalidResponse
            }
            let payload = try await updateRoutine(jobId: jobId, patch: patch)
            return ResponseFrame(type: "res", id: UUID().uuidString, ok: true, payload: AnyCodable(payload), error: nil)

        case "cron.run":
            guard let jobId = params?["jobId"] as? String else {
                throw GatewayError.invalidResponse
            }
            let payload = try await triggerRoutine(jobId: jobId)
            return ResponseFrame(type: "res", id: UUID().uuidString, ok: true, payload: AnyCodable(payload), error: nil)

        default:
            return ResponseFrame(
                type: "res",
                id: UUID().uuidString,
                ok: false,
                payload: nil,
                error: ErrorShape(code: "unsupported_method", message: "IronClaw 客户端暂未实现方法：\(method)", retryable: false)
            )
        }
    }

    func streamChat(message: String, sessionKey: String, model: String = "main") -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    _ = model
                    log("开始聊天会话 \(sessionKey)")
                    let threadId = try await resolveThreadID(sessionKey: sessionKey)
                    let baselineHistory = try await fetchThreadHistory(threadId: threadId)
                    try await sendThreadMessage(threadId: threadId, content: message)
                    let poll = try await waitForThreadTurn(threadId: threadId, afterTurnCount: baselineHistory.turns.count)
                    let reply = (poll.latestTurn.response ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    if !reply.isEmpty {
                        log("聊天响应成功，thread=\(threadId)")
                        continuation.yield(reply)
                    } else {
                        log("聊天响应完成但内容为空，thread=\(threadId)")
                    }
                    continuation.finish()
                } catch {
                    log("聊天失败: \(error.localizedDescription)")
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func resolveThreadID(sessionKey: String) async throws -> String {
        if let existing = threadIDsBySessionKey[sessionKey], !existing.isEmpty {
            return existing
        }
        if UUID(uuidString: sessionKey) != nil {
            threadIDsBySessionKey[sessionKey] = sessionKey
            return sessionKey
        }
        let created = try await createThread()
        threadIDsBySessionKey[sessionKey] = created.id
        return created.id
    }

    private func createThread() async throws -> IronClawThreadInfo {
        let cfg = try requireConfig()
        let token = try requireToken(cfg)
        let url = try buildURL(baseURL: cfg.httpBaseURL, path: "api/chat/thread/new")

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: req)
        try validateHTTPResponse(response, data: data, path: "api/chat/thread/new")
        return try snakeCaseDecoder.decode(IronClawThreadInfo.self, from: data)
    }

    private func sendThreadMessage(threadId: String, content: String) async throws {
        let cfg = try requireConfig()
        let token = try requireToken(cfg)
        let url = try buildURL(baseURL: cfg.httpBaseURL, path: "api/chat/send")

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "thread_id": threadId,
            "content": content,
            "timezone": TimeZone.current.identifier,
        ])

        let (data, response) = try await URLSession.shared.data(for: req)
        try validateHTTPResponse(response, data: data, path: "api/chat/send")
    }

    private func fetchThreadHistory(threadId: String) async throws -> IronClawThreadHistoryResponse {
        let cfg = try requireConfig()
        let token = try requireToken(cfg)
        let encodedThreadId = threadId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? threadId
        let url = try buildURL(baseURL: cfg.httpBaseURL, path: "api/chat/history?thread_id=\(encodedThreadId)")

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: req)
        try validateHTTPResponse(response, data: data, path: "api/chat/history")
        return try snakeCaseDecoder.decode(IronClawThreadHistoryResponse.self, from: data)
    }

    private func waitForThreadTurn(threadId: String, afterTurnCount: Int, timeout: TimeInterval = 45) async throws -> IronClawThreadPollResult {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let history = try await fetchThreadHistory(threadId: threadId)
            if let latestTurn = history.turns.last,
               history.turns.count > afterTurnCount,
               latestTurn.isTerminal {
                return IronClawThreadPollResult(history: history, latestTurn: latestTurn)
            }
            try await Task.sleep(nanoseconds: 300_000_000)
        }
        throw GatewayError.serverError(408, type: "timeout", message: "等待 IronClaw 对话结果超时")
    }

    private var snakeCaseDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    private func mapThreadHistoryMessages(_ history: IronClawThreadHistoryResponse) -> [[String: Any]] {
        history.turns.enumerated().flatMap { index, turn -> [[String: Any]] in
            var items: [[String: Any]] = []
            let timestamp = Self.timestampMs(from: turn.startedAt)
            let userText = turn.userInput.trimmingCharacters(in: .whitespacesAndNewlines)
            if !userText.isEmpty {
                items.append([
                    "id": "\(turn.turnNumber ?? index)-user",
                    "timestamp": timestamp,
                    "role": "user",
                    "content": [["type": "text", "text": userText]],
                ])
            }
            let assistantText = (turn.response ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !assistantText.isEmpty {
                items.append([
                    "id": "\(turn.turnNumber ?? index)-assistant",
                    "timestamp": timestamp,
                    "role": "assistant",
                    "content": [["type": "text", "text": assistantText]],
                ])
            }
            return items
        }
    }

    private static func timestampMs(from iso8601: String?) -> Int {
        guard let iso8601,
              let date = ISO8601DateFormatter().date(from: iso8601) else {
            return Int(Date().timeIntervalSince1970 * 1000)
        }
        return Int(date.timeIntervalSince1970 * 1000)
    }

    private func fetchGatewayStatus(config: ConnectionConfig) async throws -> IronClawGatewayStatus? {
        let token = try requireToken(config)
        let candidatePaths = ["api/gateway/status", "health/detailed", "health"]
        for path in candidatePaths {
            do {
                let url = try buildURL(baseURL: config.httpBaseURL, path: path)
                var req = URLRequest(url: url)
                req.httpMethod = "GET"
                req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                let (data, response) = try await URLSession.shared.data(for: req)
                try validateHTTPResponse(response, data: data, path: path)
                if let status = try? snakeCaseDecoder.decode(IronClawGatewayStatus.self, from: data) {
                    return status
                }
            } catch {
                continue
            }
        }
        return nil
    }

    private func fetchRoutines(includeDisabled: Bool) async throws -> [IronClawRoutineInfo] {
        let cfg = try requireConfig()
        let token = try requireToken(cfg)
        let url = try buildURL(baseURL: cfg.httpBaseURL, path: "api/routines")

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: req)
        try validateHTTPResponse(response, data: data, path: "api/routines")
        let decoded = try snakeCaseDecoder.decode(IronClawRoutineListResponse.self, from: data)
        if includeDisabled {
            return decoded.routines
        }
        return decoded.routines.filter { $0.enabled ?? true }
    }

    private func updateRoutine(jobId: String, patch: [String: Any]) async throws -> [String: Any] {
        guard patch["schedule"] == nil,
              patch["name"] == nil,
              let enabled = patch["enabled"] as? Bool else {
            throw GatewayError.serverError(400, type: "unsupported_patch", message: "当前 IronClaw 部署仅支持启用或停用现有任务")
        }

        let cfg = try requireConfig()
        let token = try requireToken(cfg)
        let escapedJobId = jobId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? jobId
        let url = try buildURL(baseURL: cfg.httpBaseURL, path: "api/routines/\(escapedJobId)/toggle")

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["enabled": enabled])

        let (data, response) = try await URLSession.shared.data(for: req)
        try validateHTTPResponse(response, data: data, path: "api/routines/\(escapedJobId)/toggle")
        return ["ok": true, "jobId": jobId, "enabled": enabled]
    }

    private func triggerRoutine(jobId: String, mode: String = "force") async throws -> [String: Any] {
        let cfg = try requireConfig()
        let token = try requireToken(cfg)
        let escapedJobId = jobId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? jobId
        let url = try buildURL(baseURL: cfg.httpBaseURL, path: "api/routines/\(escapedJobId)/trigger")

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["mode": mode])

        let (data, response) = try await URLSession.shared.data(for: req)
        try validateHTTPResponse(response, data: data, path: "api/routines/\(escapedJobId)/trigger")
        return ["ok": true, "jobId": jobId, "mode": mode]
    }

    private static func cronJobPayload(from routine: IronClawRoutineInfo) -> [String: Any] {
        var schedule: [String: Any] = [
            "kind": routine.triggerType ?? "routine"
        ]
        if let expr = routine.triggerSummary ?? routine.triggerRaw ?? routine.description ?? routine.name {
            schedule["expr"] = expr
        }

        var payload: [String: Any] = [:]
        if let kind = routine.actionType {
            payload["kind"] = kind
        }
        if let text = routine.description {
            payload["text"] = text
            payload["message"] = text
        }

        return [
            "id": routine.id,
            "name": routine.name as Any,
            "enabled": routine.enabled ?? true,
            "schedule": schedule,
            "payload": payload,
        ]
    }

    private func mappedChatHistoryPayload(sessionKey: String, history: IronClawThreadHistoryResponse) -> [String: Any] {
        [
            "sessionKey": sessionKey,
            "sessionId": history.threadId,
            "thinkingLevel": "off",
            "messages": mapThreadHistoryMessages(history),
        ]
    }

    private func sessionsListPayload(limit: Int) async throws -> [String: Any] {
        let payload = try await invokeTool(tool: "sessions_list", args: ["limit": limit])
        return payload
    }

    private func mappedSessionsListResponse(limit: Int) async throws -> ResponseFrame {
        let payload = try await sessionsListPayload(limit: limit)
        return ResponseFrame(type: "res", id: UUID().uuidString, ok: true, payload: AnyCodable(payload), error: nil)
    }

    private func mappedChatHistoryResponse(sessionKey: String, limit: Int, includeTools: Bool) async throws -> ResponseFrame {
        _ = includeTools
        if let threadId = threadIDsBySessionKey[sessionKey] ?? (UUID(uuidString: sessionKey) != nil ? sessionKey : nil) {
            let history = try await fetchThreadHistory(threadId: threadId)
            let payload = mappedChatHistoryPayload(sessionKey: sessionKey, history: history)
            return ResponseFrame(type: "res", id: UUID().uuidString, ok: true, payload: AnyCodable(payload), error: nil)
        }

        let payload = try await invokeTool(
            tool: "sessions_history",
            args: [
                "sessionKey": sessionKey,
                "limit": limit,
                "includeTools": includeTools,
            ]
        )
        return ResponseFrame(type: "res", id: UUID().uuidString, ok: true, payload: AnyCodable(payload), error: nil)
    }

    private func mappedConnectionMetadata(config: ConnectionConfig) async {
        if let status = try? await fetchGatewayStatus(config: config) {
            serverVersion = status.version ?? serverVersion
            uptimeMs = Int((status.uptimeSeconds ?? 0) * 1000)
        }
    }

    private struct IronClawThreadInfo: Decodable {
        let id: String
    }

    private struct IronClawThreadHistoryResponse: Decodable {
        let threadId: String
        let turns: [IronClawThreadTurn]
        let hasMore: Bool
    }

    private struct IronClawThreadTurn: Decodable {
        let turnNumber: Int?
        let userInput: String
        let response: String?
        let state: String
        let startedAt: String?

        var isTerminal: Bool {
            let normalized = state.lowercased()
            return normalized.contains("completed") || normalized.contains("failed") || normalized.contains("accepted")
        }
    }

    private struct IronClawThreadPollResult {
        let history: IronClawThreadHistoryResponse
        let latestTurn: IronClawThreadTurn
    }

    private struct IronClawGatewayStatus: Decodable {
        let status: String?
        let version: String?
        let uptimeSeconds: Double?
    }

    private struct IronClawRoutineListResponse: Decodable {
        let routines: [IronClawRoutineInfo]
    }

    private struct IronClawRoutineInfo: Decodable {
        let id: String
        let name: String?
        let description: String?
        let enabled: Bool?
        let triggerType: String?
        let triggerRaw: String?
        let triggerSummary: String?
        let actionType: String?
    }

    func onEvent(_ eventName: String, handler: @escaping (AnyCodable?) -> Void) {
        eventHandlers[eventName, default: []].append(handler)
    }

    func removeAllEventHandlers(for eventName: String) {
        eventHandlers.removeValue(forKey: eventName)
    }

    private func fetchModels(config: ConnectionConfig) async throws -> IronClawModelsEnvelope {
        let token = try requireToken(config)
        let url = try buildURL(baseURL: config.httpBaseURL, path: "v1/models")
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: req)
        try validateHTTPResponse(response, data: data, path: "v1/models")
        return try decoder.decode(IronClawModelsEnvelope.self, from: data)
    }

    private func invokeTool(tool: String, args: [String: Any]) async throws -> [String: Any] {
        let cfg = try requireConfig()
        let token = try requireToken(cfg)
        let url = try buildURL(baseURL: cfg.httpBaseURL, path: "tools/invoke")

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["tool": tool, "args": args])

        let (data, response) = try await URLSession.shared.data(for: req)
        try validateHTTPResponse(response, data: data, path: "tools/invoke")

        let envelope = try decoder.decode(IronClawToolInvokeEnvelope.self, from: data)
        guard envelope.ok else {
            throw GatewayError.invalidResponse
        }

        let text = envelope.result.content.first?.text ?? "{}"
        guard let nestedData = text.data(using: .utf8) else {
            throw GatewayError.invalidResponse
        }

        let json = try JSONSerialization.jsonObject(with: nestedData)
        guard let payload = json as? [String: Any] else {
            throw GatewayError.invalidResponse
        }
        return payload
    }

    private func requireConfig() throws -> ConnectionConfig {
        guard let cfg = config else { throw GatewayError.noConfig }
        return cfg
    }

    private func requireToken(_ config: ConnectionConfig) throws -> String {
        let trimmed = config.token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw GatewayError.noToken }
        return trimmed
    }

    private func buildURL(baseURL: URL, path: String) throws -> URL {
        let trimmedBase = baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let trimmedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(trimmedBase)/\(trimmedPath)") else {
            throw GatewayError.invalidResponse
        }
        return url
    }

    private func validateHTTPResponse(_ response: URLResponse, data: Data, path: String) throws {
        guard let http = response as? HTTPURLResponse else {
            throw GatewayError.invalidResponse
        }

        let body = String(data: data, encoding: .utf8) ?? ""
        if (200...299).contains(http.statusCode) {
            if isLikelyControlPage(body, response: http) {
                throw GatewayError.controlPageReturned(path: path)
            }
            return
        }

        if http.statusCode == 404, path == "tools/invoke" {
            throw GatewayError.serverError(http.statusCode, type: "tool_unavailable", message: "当前 IronClaw 部署未启用工具接口（/tools/invoke），该功能不可用。")
        }

        if let envelope = try? decoder.decode(IronClawAPIErrorEnvelope.self, from: data),
           let error = envelope.error {
            throw GatewayError.serverError(http.statusCode, type: error.type, message: error.message)
        }

        throw GatewayError.httpError(http.statusCode, body: body)
    }

    private func isLikelyControlPage(_ body: String, response: HTTPURLResponse) -> Bool {
        let contentType = response.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
        let sample = body.prefix(512).lowercased()
        guard contentType.contains("text/html") || sample.contains("<!doctype html") || sample.contains("<html") else {
            return false
        }

        return sample.contains("openclaw") ||
               sample.contains("ironclaw") ||
               sample.contains("control ui") ||
               sample.contains("<head") ||
               sample.contains("<body")
    }

    private func clearServerInfo() {
        serverVersion = ""
        serverHost = ""
        connId = ""
        uptimeMs = 0
    }
}

private struct IronClawModelsEnvelope: Decodable {
    let data: [IronClawModel]?

    struct IronClawModel: Decodable {
        let id: String
    }
}

private struct IronClawToolInvokeEnvelope: Decodable {
    struct Result: Decodable {
        struct Content: Decodable {
            let type: String
            let text: String
        }

        let content: [Content]
    }

    let ok: Bool
    let result: Result
}

private struct IronClawAPIErrorEnvelope: Decodable {
    struct ErrorDetail: Decodable {
        let type: String
        let message: String
    }

    let error: ErrorDetail?
}

enum GatewayError: LocalizedError {
    case noConfig
    case noToken
    case notConnected
    case invalidResponse
    case controlPageReturned(path: String)
    case httpError(Int, body: String)
    case serverError(Int, type: String, message: String)

    var errorDescription: String? {
        switch self {
        case .noConfig:
            return "未找到 IronClaw 配置"
        case .noToken:
            return "未找到 IronClaw Bearer Token"
        case .notConnected:
            return "未连接到 IronClaw 服务"
        case .invalidResponse:
            return "IronClaw 返回了无效响应"
        case .controlPageReturned(let path):
            return "当前地址返回的是控制页面，不是 API 根地址。请改用真正提供 /\(path) 接口的 IronClaw 服务地址。"
        case .httpError(let code, let body):
            return "IronClaw HTTP \(code)。响应内容：\(body.isEmpty ? "（空）" : body)"
        case .serverError(let code, _, let message):
            return "IronClaw HTTP \(code)：\(message)"
        }
    }
}
