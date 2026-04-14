import Foundation

struct SessionInfo: Identifiable, Codable {
    var id: String { key }
    let key: String
    let agentId: String?
    let label: String?
    let lastActive: Date?
    let derivedTitle: String?
    let lastMessage: String?
    let kind: String?

    var displayTitle: String {
        derivedTitle ?? label ?? key
    }
}

struct CronJob: Identifiable, Codable {
    let id: String
    let name: String?
    let enabled: Bool
    let schedule: CronSchedule?
    let payload: CronPayload?

    struct CronSchedule: Codable {
        let kind: String?
        let expr: String?
        let everyMs: Int?
    }

    struct CronPayload: Codable {
        let kind: String?
        let text: String?
        let message: String?
    }

    var displayName: String {
        name ?? id.prefix(8).description
    }

    var scheduleDescription: String {
        guard let schedule else { return "未知" }
        switch schedule.kind {
        case "cron": return schedule.expr ?? "cron"
        case "every":
            if let ms = schedule.everyMs {
                let mins = ms / 60_000
                return mins >= 60 ? "每\(mins / 60)小时" : "每\(mins)分钟"
            }
            return "间隔"
        case "at": return "单次"
        default: return schedule.kind ?? "未知"
        }
    }
}

struct NodeInfo: Identifiable, Codable {
    var id: String { deviceId }
    let deviceId: String
    let host: String?
    let platform: String?
    let version: String?
    let caps: [String]?
    let lastSeen: Date?

    var displayName: String {
        host ?? deviceId.prefix(12).description
    }

    var platformIcon: String {
        switch platform?.lowercased() {
        case "ios": return "iphone"
        case "macos": return "laptopcomputer"
        case "linux": return "server.rack"
        case "android": return "smartphone"
        default: return "desktopcomputer"
        }
    }
}
