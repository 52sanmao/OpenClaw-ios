import Foundation

struct ConnectionConfig: Codable, Equatable {
    var host: String       // host 或完整 IronClaw HTTP 地址
    var port: Int          // host-only 输入时的默认端口
    var useTLS: Bool       // host-only 输入时决定 http / https
    var token: String      // IronClaw Bearer Token

    static func normalizeGatewayEndpoint(_ rawValue: String, fallbackPort: Int, useTLS: Bool) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        if let components = URLComponents(string: trimmed),
           let scheme = components.scheme?.lowercased() {
            switch scheme {
            case "http", "https":
                var normalized = components
                normalized.scheme = scheme
                normalized.user = nil
                normalized.password = nil
                if normalized.path.isEmpty {
                    normalized.path = ""
                }
                normalized.query = nil
                normalized.fragment = nil
                return normalized.url

            case "ws", "wss":
                var normalized = components
                normalized.scheme = (scheme == "wss") ? "https" : "http"
                normalized.user = nil
                normalized.password = nil
                if normalized.path.isEmpty {
                    normalized.path = ""
                }
                normalized.query = nil
                normalized.fragment = nil
                return normalized.url

            default:
                break
            }
        }

        let scheme = useTLS ? "https" : "http"
        return URL(string: "\(scheme)://\(trimmed):\(fallbackPort)")
    }

    var httpBaseURL: URL {
        Self.normalizeGatewayEndpoint(host, fallbackPort: port, useTLS: useTLS)
            ?? URL(string: "http://127.0.0.1:8642")!
    }

    var displayName: String {
        let baseURL = httpBaseURL
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return baseURL.absoluteString
        }
        components.user = nil
        components.password = nil
        components.query = nil
        components.fragment = nil
        return components.string ?? baseURL.absoluteString
    }
}

// MARK: - Keychain Storage

enum ConnectionStore {
    private static let key = "ai.openclaw.mobile.connection"

    static func save(_ config: ConnectionConfig) {
        guard let data = try? JSONEncoder().encode(config) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func load() -> ConnectionConfig? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ConnectionConfig.self, from: data)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
