import SwiftUI

struct ChatView: View {
    @EnvironmentObject var gateway: GatewayClient
    @StateObject private var chatService = ChatService(gateway: .shared)
    @StateObject private var approvalService = ExecApprovalService(gateway: .shared)
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        ZStack {
            Color.surfaceBase.ignoresSafeArea()

            VStack(spacing: 0) {
                // Nav bar
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        SectionLabel(text: "当前会话")
                        Text("聊天")
                            .font(.headline(24))
                            .foregroundStyle(Color.textPrimary)
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        StatusLED(color: gateway.connectionState == .connected ? Color.ocSuccess : Color.ocError, pulsing: gateway.connectionState == .connected)
                        Text(gateway.connectionState == .connected ? "在线" : "离线")
                            .font(.label(9, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(gateway.connectionState == .connected ? Color.ocSuccess : Color.ocError)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .glassBar()

                // Exec approval banner
                ExecApprovalBanner(service: approvalService)
                    .animation(.spring(duration: 0.3), value: approvalService.pendingApprovals.count)

                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(chatService.messages) { msg in
                                VanguardBubble(message: msg)
                                    .id(msg.id)
                            }
                            if chatService.isAgentTyping {
                                VanguardStreamingBubble(text: chatService.currentStreamText)
                                    .id("streaming")
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                    }
                    .onChange(of: chatService.messages.count) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            if let lastId = chatService.messages.last?.id {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: chatService.isAgentTyping) {
                        if chatService.isAgentTyping {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo("streaming", anchor: .bottom)
                            }
                        }
                    }
                }

                // Input bar
                HStack(spacing: 12) {
                    TextField("输入消息...", text: $inputText, axis: .vertical)
                        .font(.body(14))
                        .foregroundStyle(Color.textPrimary)
                        .textFieldStyle(.plain)
                        .lineLimit(1...6)
                        .focused($isInputFocused)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.surfaceContainerLow)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .strokeBorder(isInputFocused ? Color.ocPrimary.opacity(0.3) : Color.white.opacity(0.03), lineWidth: 1)
                        )
                        .onSubmit { sendMessage() }

                    Button { sendMessage() } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(canSend ? .black : Color.textTertiary)
                            .frame(width: 36, height: 36)
                            .background(canSend ? Color.ocPrimary : Color.surfaceContainerHigh)
                            .clipShape(Circle())
                    }
                    .disabled(!canSend)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .glassBar()
            }
        }
        .task { await chatService.loadHistory() }
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespaces).isEmpty && !chatService.isAgentTyping
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        inputText = ""
        Haptics.impact(.light)
        Task { try? await chatService.send(text) }
    }
}

// MARK: - Vanguard Message Bubble

struct VanguardBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 48) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Group {
                    if message.role == .assistant && message.content.contains("```") {
                        RichMarkdownView(content: message.content)
                    } else if message.role == .assistant {
                        MarkdownText(content: message.content)
                            .font(.body(14))
                    } else {
                        Text(message.content)
                            .font(.body(14))
                    }
                }
                .foregroundStyle(message.role == .user ? .black : Color.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(bubbleBackground)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(bubbleBorder, lineWidth: 1)
                )

                Text(message.timestamp, style: .time)
                    .font(.label(9))
                    .foregroundStyle(Color.textTertiary)
            }

            if message.role != .user { Spacer(minLength: 48) }
        }
        .contextMenu {
            Button {
                UIPasteboard.general.string = message.content
                Haptics.notification(.success)
            } label: {
                Label("复制", systemImage: "doc.on.doc")
            }
        }
    }

    private var bubbleBackground: Color {
        switch message.role {
        case .user: Color.ocPrimary
        case .assistant: .surfaceContainerLow
        case .system: .surfaceContainer
        }
    }

    private var bubbleBorder: Color {
        switch message.role {
        case .user: .clear
        case .assistant: .white.opacity(0.03)
        case .system: Color.ocError.opacity(0.2)
        }
    }
}

// MARK: - Streaming Bubble

struct VanguardStreamingBubble: View {
    let text: String
    @State private var dotCount = 0
    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                if text.isEmpty {
                    HStack(spacing: 5) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(Color.ocPrimary.opacity(i <= dotCount ? 1 : 0.2))
                                .frame(width: 6, height: 6)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(Color.surfaceContainerLow)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .ghostBorder()
                    .onReceive(timer) { _ in dotCount = (dotCount + 1) % 3 }
                } else {
                    MarkdownText(content: text)
                        .font(.body(14))
                        .foregroundStyle(Color.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.surfaceContainerLow)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .ghostBorder()
                }
            }
            Spacer(minLength: 48)
        }
    }
}
