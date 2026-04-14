import SwiftUI

/// Renders markdown content using iOS 15+ AttributedString.
struct MarkdownText: View {
    let content: String

    var body: some View {
        if let attributed = try? AttributedString(markdown: content, options: .init(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )) {
            Text(attributed)
                .textSelection(.enabled)
        } else {
            Text(content)
                .textSelection(.enabled)
        }
    }
}

/// Renders full markdown with code blocks as separate styled views.
struct RichMarkdownView: View {
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(parseBlocks().enumerated()), id: \.offset) { _, block in
                switch block {
                case .text(let text):
                    MarkdownText(content: text)
                        .font(.body(14))
                case .code(let lang, let code):
                    CodeBlockView(language: lang, code: code)
                }
            }
        }
    }

    private enum Block {
        case text(String)
        case code(String?, String)
    }

    private func parseBlocks() -> [Block] {
        var blocks: [Block] = []
        var remaining = content
        let codePattern = "```"

        while let startRange = remaining.range(of: codePattern) {
            let textBefore = String(remaining[remaining.startIndex..<startRange.lowerBound])
            if !textBefore.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                blocks.append(.text(textBefore))
            }

            remaining = String(remaining[startRange.upperBound...])

            var lang: String? = nil
            if let newline = remaining.firstIndex(of: "\n") {
                let firstLine = String(remaining[remaining.startIndex..<newline]).trimmingCharacters(in: .whitespaces)
                if !firstLine.isEmpty && firstLine.count < 20 && !firstLine.contains(" ") {
                    lang = firstLine
                    remaining = String(remaining[remaining.index(after: newline)...])
                }
            }

            if let endRange = remaining.range(of: codePattern) {
                let code = String(remaining[remaining.startIndex..<endRange.lowerBound])
                blocks.append(.code(lang, code.trimmingCharacters(in: .newlines)))
                remaining = String(remaining[endRange.upperBound...])
            } else {
                blocks.append(.code(lang, remaining))
                remaining = ""
            }
        }

        if !remaining.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            blocks.append(.text(remaining))
        }

        return blocks
    }
}

/// Vanguard-styled code block with copy button.
struct CodeBlockView: View {
    let language: String?
    let code: String
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                if let language {
                    Text(language.uppercased())
                        .font(.label(9, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Color.textTertiary)
                }
                Spacer()
                Button {
                    UIPasteboard.general.string = code
                    copied = true
                    Haptics.notification(.success)
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        copied = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        Text(copied ? "已复制" : "复制")
                            .font(.label(9, weight: .bold))
                            .tracking(1)
                    }
                    .foregroundStyle(copied ? Color.ocSuccess : Color.textTertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.surfaceContainerHighest)

            // Code
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color.textSecondary)
                    .textSelection(.enabled)
                    .padding(12)
            }
            .background(Color.surfaceContainer)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.03), lineWidth: 1)
        )
    }
}
