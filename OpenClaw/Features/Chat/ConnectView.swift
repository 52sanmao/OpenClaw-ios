import SwiftUI

struct ConnectView: View {
    @EnvironmentObject var gateway: GatewayClient
    @StateObject private var discovery = BonjourDiscovery()
    @State private var host = ""
    @State private var port = "18789"
    @State private var token = ""
    @State private var useTLS = false
    @State private var isConnecting = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.surfaceLowest.ignoresSafeArea()
            BlueprintGrid()

            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    // Logo
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.ocPrimary)
                            .shadow(color: Color.ocPrimary.opacity(0.3), radius: 12)

                        Text("OpenClaw")
                            .font(.headline(32))
                            .foregroundStyle(Color.textPrimary)

                        Text("GATEWAY CONNECTION")
                            .font(.label(10, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(Color.textTertiary)
                    }
                    .padding(.top, 60)

                    // Discovered gateways
                    if !discovery.gateways.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionLabel(text: "Discovered on Network")

                            ForEach(discovery.gateways) { gw in
                                Button {
                                    host = gw.host
                                    port = String(gw.port)
                                    useTLS = gw.useTLS
                                    Haptics.selection()
                                } label: {
                                    HStack(spacing: 12) {
                                        IconAvatar(icon: "antenna.radiowaves.left.and.right", size: 40)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(gw.displayName ?? gw.name)
                                                .font(.body(14, weight: .semibold))
                                                .foregroundStyle(Color.textPrimary)
                                            Text("\(gw.host):\(gw.port)")
                                                .font(.label(11))
                                                .foregroundStyle(Color.textTertiary)
                                        }
                                        Spacer()
                                        if host == gw.host && port == String(gw.port) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(Color.ocPrimary)
                                        }
                                    }
                                    .padding(14)
                                    .vanguardCard(elevated: true)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else if discovery.isSearching {
                        HStack(spacing: 8) {
                            ProgressView().tint(.ocPrimary)
                            Text("SCANNING NETWORK")
                                .font(.label(10, weight: .bold))
                                .tracking(2)
                                .foregroundStyle(Color.textTertiary)
                        }
                    }

                    // Connection form
                    VStack(alignment: .leading, spacing: 16) {
                        SectionLabel(text: "Manual Connection")

                        VanguardField(title: "HOST", placeholder: "192.168.1.10 or mybox.tail...", text: $host)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)

                        VanguardField(title: "PORT", placeholder: "18789", text: $port)
                            .keyboardType(.numberPad)

                        VanguardField(title: "TOKEN", placeholder: "Gateway auth token", text: $token, isSecure: true)

                        HStack {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(Color.textTertiary)
                            Text("USE TLS (WSS://)")
                                .font(.label(11, weight: .medium))
                                .tracking(1)
                                .foregroundStyle(Color.textSecondary)
                            Spacer()
                            Toggle("", isOn: $useTLS)
                                .labelsHidden()
                                .tint(.ocPrimary)
                        }
                        .padding(.horizontal, 4)
                    }

                    // Error
                    if let errorMessage {
                        HStack(spacing: 8) {
                            StatusLED(color: Color.ocError)
                            Text(errorMessage)
                                .font(.body(12))
                                .foregroundStyle(Color.ocError)
                        }
                    }

                    // Connect button
                    Button { connect() } label: {
                        HStack {
                            if isConnecting {
                                ProgressView().tint(.black)
                            }
                            Text(isConnecting ? "CONNECTING" : "CONNECT")
                                .font(.label(14, weight: .bold))
                                .tracking(2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            canConnect
                                ? LinearGradient(colors: [.ocPrimary, .ocPrimaryContainer], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [.surfaceContainerHigh, .surfaceContainerHigh], startPoint: .leading, endPoint: .trailing)
                        )
                        .foregroundStyle(canConnect ? .black : Color.textTertiary)
                        .clipShape(Capsule())
                    }
                    .disabled(!canConnect || isConnecting)

                    // QR scan
                    Button {} label: {
                        HStack(spacing: 6) {
                            Image(systemName: "qrcode.viewfinder")
                            Text("SCAN QR CODE")
                                .font(.label(11, weight: .medium))
                                .tracking(1.5)
                        }
                        .foregroundStyle(Color.ocPrimary)
                    }
                    .frame(maxWidth: .infinity)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
            }
        }
        .onAppear {
            loadSavedConfig()
            discovery.startBrowsing()
            if let saved = ConnectionStore.load(), !saved.host.isEmpty, !saved.token.isEmpty {
                connect()
            }
        }
    }

    private var canConnect: Bool {
        !host.trimmingCharacters(in: .whitespaces).isEmpty &&
        !port.isEmpty &&
        !token.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func loadSavedConfig() {
        if let saved = ConnectionStore.load() {
            host = saved.host
            port = String(saved.port)
            token = saved.token
            useTLS = saved.useTLS
        }
    }

    private func connect() {
        guard let portNum = Int(port) else {
            errorMessage = "Invalid port number"
            return
        }
        let config = ConnectionConfig(
            host: host.trimmingCharacters(in: .whitespaces),
            port: portNum,
            useTLS: useTLS,
            token: token.trimmingCharacters(in: .whitespaces)
        )
        isConnecting = true
        errorMessage = nil
        Task {
            do {
                try await gateway.connect(config: config)
                isConnecting = false
            } catch {
                isConnecting = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Vanguard Input Field

struct VanguardField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var isSecure = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.label(10, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(Color.textTertiary)

            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .font(.body(14))
            .foregroundStyle(Color.textPrimary)
            .focused($isFocused)
            .textFieldStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.surfaceContainerLow)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        isFocused ? Color.ocPrimary.opacity(0.4) : Color.white.opacity(0.03),
                        lineWidth: 1
                    )
            )
        }
    }
}
