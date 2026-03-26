import Foundation
import Network

/// Discovers OpenClaw Gateways on the local network via Bonjour.
@MainActor
final class BonjourDiscovery: ObservableObject {
    struct Gateway: Identifiable, Equatable {
        let id: String // endpoint hash
        let name: String
        let host: String
        let port: Int
        let useTLS: Bool
        let displayName: String?
        let serverVersion: String?
        let tailnetDns: String?
    }

    @Published var gateways: [Gateway] = []
    @Published var isSearching = false

    private var browser: NWBrowser?
    private var connections: [NWConnection] = []

    func startBrowsing() {
        isSearching = true
        gateways = []

        let params = NWParameters()
        params.includePeerToPeer = true

        let descriptor = NWBrowser.Descriptor.bonjour(
            type: "_openclaw-gw._tcp",
            domain: "local."
        )

        let browser = NWBrowser(for: descriptor, using: params)
        self.browser = browser

        browser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready:
                    self?.isSearching = true
                case .failed, .cancelled:
                    self?.isSearching = false
                default:
                    break
                }
            }
        }

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in
                self?.handleResults(results)
            }
        }

        browser.start(queue: .main)

        // Auto-stop after 10 seconds
        Task {
            try? await Task.sleep(for: .seconds(10))
            stopBrowsing()
        }
    }

    func stopBrowsing() {
        browser?.cancel()
        browser = nil
        isSearching = false
    }

    private func handleResults(_ results: Set<NWBrowser.Result>) {
        var discovered: [Gateway] = []

        for result in results {
            guard case .service(let name, _, _, _) = result.endpoint else { continue }

            // Use the service name as host, default port
            let host = decodeBonjourName(name) + ".local"
            let port = 18789

            discovered.append(Gateway(
                id: "\(host):\(port)",
                name: name,
                host: host,
                port: port,
                useTLS: false,
                displayName: decodeBonjourName(name),
                serverVersion: nil,
                tailnetDns: nil
            ))
        }

        gateways = discovered
    }

    /// Decode Bonjour escaped names (e.g. `\032` -> space)
    private func decodeBonjourName(_ name: String) -> String {
        var result = ""
        let chars = Array(name)
        var i = 0
        while i < chars.count {
            if chars[i] == "\\" && i + 3 < chars.count {
                let digits = String(chars[(i+1)...(i+3)])
                if let code = UInt8(digits) {
                    result.append(Character(Unicode.Scalar(code)))
                    i += 4
                    continue
                }
            }
            result.append(chars[i])
            i += 1
        }
        return result
    }
}

// TXT record parsing handled inline for simplicity.
// Full TXT extraction can be added when resolving individual services.
