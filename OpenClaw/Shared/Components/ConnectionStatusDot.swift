import SwiftUI

struct ConnectionStatusDot: View {
    let state: GatewayClient.ConnectionState

    var body: some View {
        HStack(spacing: 5) {
            StatusLED(color: dotColor, pulsing: state == .connected)
            Text(label.uppercased())
                .font(.label(9, weight: .bold))
                .tracking(1)
                .foregroundStyle(dotColor)
        }
    }

    private var dotColor: Color {
        switch state {
        case .connected: Color.ocSuccess
        case .connecting: Color.ocTertiary
        case .disconnected: Color.textTertiary
        case .error: Color.ocError
        }
    }

    private var label: String {
        switch state {
        case .connected: "Live"
        case .connecting: "Sync"
        case .disconnected: "Off"
        case .error: "Error"
        }
    }
}
