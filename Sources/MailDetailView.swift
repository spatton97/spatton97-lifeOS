import SwiftUI
import SwiftData
import WebKit

// MARK: - Detail

struct MailDetailView: View {
    let message: GmailAPI.MailMessageItem
    let mailboxID: UUID?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorBlindMode) private var colorBlind

    @State private var bodyPlain: String?
    @State private var bodyHTML: String?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text(message.subject)
                    .font(.title3.weight(.semibold))
                LabeledContent("From", value: message.from.isEmpty ? "—" : message.from)
                if let date = message.date {
                    LabeledContent("Date", value: date.formatted(date: .abbreviated, time: .shortened))
                }
            }
            .padding()
            Divider()
            Group {
                if isLoading && bodyPlain == nil && bodyHTML == nil {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let bodyHTML, !bodyHTML.isEmpty {
                    HTMLMailWebView(html: bodyHTML)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let bodyPlain, !bodyPlain.isEmpty {
                    ScrollView {
                        Text(bodyPlain)
                            .font(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                } else if !message.snippet.isEmpty {
                    ScrollView {
                        Text(message.snippet)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                } else {
                    Text("No body available.")
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(LifeOSAccent.danger(colorBlind: colorBlind))
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
        }
        .navigationTitle("Message")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadBody() }
    }

    private func loadBody() async {
        if let existing = message.bodyPlain, !existing.isEmpty {
            bodyPlain = existing
        }
        if let existingHTML = message.bodyHTML, !existingHTML.isEmpty {
            bodyHTML = existingHTML
        }
        if bodyPlain != nil || bodyHTML != nil { return }

        guard let mailboxID else {
            bodyPlain = message.snippet
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let token = try await MailSession.ensureValidAccessToken(for: mailboxID, in: modelContext)
            let detailed = try await GmailAPI.fetchMessageDetail(accessToken: token, id: message.id)
            bodyPlain = detailed.bodyPlain
            bodyHTML = detailed.bodyHTML
            if bodyPlain == nil && bodyHTML == nil {
                bodyPlain = detailed.snippet
            }
        } catch {
            errorMessage = error.localizedDescription
            bodyPlain = message.snippet
        }
    }
}

/// Renders HTML email bodies (images + formatting) inside a sandboxed web view.
private struct HTMLMailWebView: UIViewRepresentable {
    let html: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = .systemBackground
        web.scrollView.contentInsetAdjustmentBehavior = .automatic
        return web
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let wrapped = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
        <style>
          :root { color-scheme: light dark; }
          body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; font-size: 16px; line-height: 1.45; margin: 12px; word-wrap: break-word; }
          img { max-width: 100%; height: auto; }
          a { color: #0a84ff; }
          pre, code { white-space: pre-wrap; }
        </style>
        </head>
        <body>\(html)</body>
        </html>
        """
        webView.loadHTMLString(wrapped, baseURL: nil)
    }
}
