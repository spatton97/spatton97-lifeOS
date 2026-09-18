import SwiftUI
import SwiftData
import WebKit

/// Free tier: exactly one connected Gmail mailbox, read-only inbox.
struct MailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorBlindMode) private var colorBlind

    @Query(sort: \MailMailbox.connectedAt) private var mailboxes: [MailMailbox]

    @StateObject private var auth = GmailAuthController()
    @State private var messages: [GmailAPI.MailMessageItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSubscriptionGate = false
    @State private var selectedMessage: GmailAPI.MailMessageItem?

    private var mailbox: MailMailbox? { mailboxes.first }
    private var isConfigured: Bool { GmailConfig.isConfigured }

    var body: some View {
        NavigationStack {
            Group {
                if !isConfigured {
                    setupInstructions
                } else if let mailbox {
                    inboxList(for: mailbox)
                } else {
                    connectPrompt
                }
            }
            .navigationTitle("Mail")
            .toolbar { toolbarContent }
            .alert("Subscription unlocks more mailboxes", isPresented: $showSubscriptionGate) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("The free plan includes one Gmail mailbox. A future subscription will unlock additional mailboxes. Bill auto-suggestions are also planned for a later / pro release.")
            }
            .navigationDestination(item: $selectedMessage) { message in
                MailDetailView(message: message, mailboxID: mailbox?.id)
            }
        }
        .tint(LifeOSAccent.primary(colorBlind: colorBlind))
        .task(id: mailbox?.id) {
            guard mailbox != nil else { return }
            await refreshInbox()
        }
    }

    // MARK: - Setup (missing Client ID)

    private var setupInstructions: some View {
        ContentUnavailableView {
            Label("Gmail setup needed", systemImage: "gearshape.2")
        } description: {
            Text("Add your Google OAuth iOS Client ID to the Xcode target Info, then rebuild. See SETUP.md for steps.")
        } actions: {
            VStack(alignment: .leading, spacing: 8) {
                Text("1. Create an OAuth iOS client in Google Cloud Console")
                Text("2. Paste Client ID as LifeOSGmailClientID or GIDClientID")
                Text("3. Add the reversed Client ID as a URL scheme")
                Text("Connect stays disabled until that is configured.")
                    .padding(.top, 4)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: 320, alignment: .leading)
            .padding(.horizontal)

            Button("Connect Gmail") {}
                .buttonStyle(.borderedProminent)
                .disabled(true)
        }
    }

    // MARK: - Connect

    private var connectPrompt: some View {
        ContentUnavailableView {
            Label("Mail", systemImage: "envelope.badge.shield.half.filled")
        } description: {
            Text("Connect one free Gmail mailbox for a read-only inbox. Sending and bill auto-suggestions are not included.")
        } actions: {
            Button {
                Task { await connectGmail() }
            } label: {
                if auth.isAuthenticating {
                    ProgressView()
                        .padding(.horizontal, 24)
                } else {
                    Label("Connect Gmail", systemImage: "person.crop.circle.badge.plus")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(auth.isAuthenticating)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(LifeOSAccent.danger(colorBlind: colorBlind))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - Inbox

    @ViewBuilder
    private func inboxList(for mailbox: MailMailbox) -> some View {
        List {
            Section {
                HStack {
                    Image(systemName: "envelope.fill")
                        .foregroundStyle(LifeOSAccent.primary(colorBlind: colorBlind))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mailbox.email)
                            .font(.subheadline.weight(.semibold))
                        Text("Gmail · read-only · free slot 1 of 1")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }

            Section {
                if isLoading && messages.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView("Loading inbox…")
                        Spacer()
                    }
                } else if messages.isEmpty {
                    Text("No messages in Inbox")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(messages) { message in
                        Button {
                            selectedMessage = message
                        } label: {
                            MailRowView(message: message)
                        }
                    }
                }
            } header: {
                Text("Inbox")
            } footer: {
                Text("Read-only. Bill auto-suggestions may arrive in a later / pro release.")
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(LifeOSAccent.danger(colorBlind: colorBlind))
                }
            }
        }
        .refreshable { await refreshInbox() }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if mailbox != nil {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await refreshInbox() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
                .accessibilityLabel("Refresh")
            }
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Button("Connect another mailbox…") {
                        showSubscriptionGate = true
                    }
                    Button("Disconnect", role: .destructive) {
                        disconnect()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        } else if isConfigured {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await connectGmail() }
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(auth.isAuthenticating)
                .accessibilityLabel("Connect Gmail")
            }
        }
    }

    // MARK: - Actions

    private func connectGmail() async {
        // Enforce free limit in UI before auth (and again on save).
        if mailboxes.count >= GmailConfig.freeMailboxLimit {
            showSubscriptionGate = true
            return
        }
        errorMessage = nil
        do {
            let result = try await auth.signIn()
            try saveMailbox(from: result)
            await refreshInbox()
        } catch let error as GmailAuthController.AuthError {
            if case .canceled = error { return }
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveMailbox(from result: GmailAuthController.AuthResult) throws {
        // Hard gate on the save path as well as UI.
        if mailboxes.count >= GmailConfig.freeMailboxLimit {
            showSubscriptionGate = true
            throw SaveError.limitReached
        }
        let box = MailMailbox(email: result.email, providerRaw: "gmail")
        let expiresAt = result.expiresIn.map { Date().addingTimeInterval($0) }
        let tokens = MailKeychain.TokenBundle(
            accessToken: result.accessToken,
            refreshToken: result.refreshToken,
            expiresAt: expiresAt,
            tokenType: result.tokenType,
            scope: result.scope
        )
        try MailKeychain.save(tokens: tokens, mailboxID: box.id)
        modelContext.insert(box)
        try modelContext.save()
    }

    private func disconnect() {
        guard let mailbox else { return }
        MailKeychain.delete(mailboxID: mailbox.id)
        modelContext.delete(mailbox)
        try? modelContext.save()
        messages = []
        errorMessage = nil
        selectedMessage = nil
    }

    private func refreshInbox() async {
        guard let mailbox else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let token = try await GmailTokenStore.validAccessToken(for: mailbox.id)
            messages = try await GmailAPI.fetchRecentMessages(accessToken: token, maxResults: 30)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private enum SaveError: LocalizedError {
        case limitReached
        var errorDescription: String? {
            "Subscription unlocks more mailboxes"
        }
    }
}

// MARK: - Row

private struct MailRowView: View {
    let message: GmailAPI.MailMessageItem

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.doesRelativeDateFormatting = true
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(message.from.isEmpty ? "(unknown)" : shortenedFrom(message.from))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
                if let date = message.date {
                    Text(Self.dateFormatter.string(from: date))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Text(message.subject)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(1)
            if !message.snippet.isEmpty {
                Text(message.snippet)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }

    private func shortenedFrom(_ raw: String) -> String {
        // "Name <email>" → "Name"
        if let open = raw.firstIndex(of: "<"), open > raw.startIndex {
            return String(raw[..<open]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return raw
    }
}

// MARK: - Detail

struct MailDetailView: View {
    let message: GmailAPI.MailMessageItem
    let mailboxID: UUID?

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
                    .foregroundStyle(.red)
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
            let token = try await GmailTokenStore.validAccessToken(for: mailboxID)
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

#Preview("Connect") {
    MailView()
        .modelContainer(for: [MailMailbox.self], inMemory: true)
        .environment(\.colorBlindMode, false)
}
