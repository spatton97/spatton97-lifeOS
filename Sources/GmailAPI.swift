import Foundation

/// Read-only Gmail REST helpers (profile + recent messages).
enum GmailAPI {
    struct MailMessageItem: Identifiable, Hashable {
        let id: String
        let threadId: String
        let subject: String
        let from: String
        let date: Date?
        let snippet: String
        var bodyPlain: String?
        var bodyHTML: String?
    }

    static func fetchProfileEmail(accessToken: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/profile")!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try throwIfNeeded(response: response, data: data)
        struct Profile: Decodable { let emailAddress: String }
        return try JSONDecoder().decode(Profile.self, from: data).emailAddress
    }

    /// Fetches up to `maxResults` recent inbox messages (metadata + snippet).
    static func fetchRecentMessages(accessToken: String, maxResults: Int = 30) async throws -> [MailMessageItem] {
        var listURL = URLComponents(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages")!
        listURL.queryItems = [
            URLQueryItem(name: "maxResults", value: String(maxResults)),
            URLQueryItem(name: "labelIds", value: "INBOX")
        ]
        var listReq = URLRequest(url: listURL.url!)
        listReq.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (listData, listResp) = try await URLSession.shared.data(for: listReq)
        try throwIfNeeded(response: listResp, data: listData)

        struct ListResponse: Decodable {
            struct Ref: Decodable { let id: String; let threadId: String? }
            let messages: [Ref]?
        }
        let list = try JSONDecoder().decode(ListResponse.self, from: listData)
        guard let refs = list.messages, !refs.isEmpty else { return [] }

        var items: [MailMessageItem] = []
        items.reserveCapacity(refs.count)
        try await withThrowingTaskGroup(of: MailMessageItem?.self) { group in
            for ref in refs {
                group.addTask {
                    try await fetchMessageMetadata(accessToken: accessToken, id: ref.id)
                }
            }
            for try await item in group {
                if let item { items.append(item) }
            }
        }
        return items.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }

    static func fetchMessageDetail(accessToken: String, id: String) async throws -> MailMessageItem {
        var comps = URLComponents(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/\(id)")!
        comps.queryItems = [URLQueryItem(name: "format", value: "full")]
        var request = URLRequest(url: comps.url!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try throwIfNeeded(response: response, data: data)
        return try parseMessage(data: data, includeBody: true)
    }

    // MARK: - Private

    private static func fetchMessageMetadata(accessToken: String, id: String) async throws -> MailMessageItem? {
        var comps = URLComponents(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/\(id)")!
        comps.queryItems = [
            URLQueryItem(name: "format", value: "metadata"),
            URLQueryItem(name: "metadataHeaders", value: "From"),
            URLQueryItem(name: "metadataHeaders", value: "Subject"),
            URLQueryItem(name: "metadataHeaders", value: "Date")
        ]
        var request = URLRequest(url: comps.url!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try throwIfNeeded(response: response, data: data)
        return try parseMessage(data: data, includeBody: false)
    }

    private struct APIMessage: Decodable {
        struct Payload: Decodable {
            struct Header: Decodable { let name: String; let value: String }
            struct Body: Decodable { let data: String? }
            struct Part: Decodable {
                let mimeType: String?
                let body: Body?
                let parts: [Part]?
            }
            let headers: [Header]?
            let body: Body?
            let parts: [Part]?
            let mimeType: String?
        }
        let id: String
        let threadId: String?
        let snippet: String?
        let internalDate: String?
        let payload: Payload?
    }

    private static func parseMessage(data: Data, includeBody: Bool) throws -> MailMessageItem {
        let msg = try JSONDecoder().decode(APIMessage.self, from: data)
        let headers = msg.payload?.headers ?? []
        func header(_ name: String) -> String {
            headers.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.value ?? ""
        }
        let subject = header("Subject").isEmpty ? "(no subject)" : header("Subject")
        let from = header("From")
        let date: Date? = {
            if let ms = msg.internalDate, let n = Double(ms) {
                return Date(timeIntervalSince1970: n / 1000.0)
            }
            return nil
        }()
        var plain: String?
        var html: String?
        if includeBody {
            plain = extractPlainText(from: msg.payload)
            html = extractHTML(from: msg.payload)
            // Never treat raw HTML as "plain" — that shows as code in Text views.
            if plain == nil, html == nil {
                plain = msg.snippet
            }
        }
        return MailMessageItem(
            id: msg.id,
            threadId: msg.threadId ?? msg.id,
            subject: subject,
            from: from,
            date: date,
            snippet: msg.snippet ?? "",
            bodyPlain: plain,
            bodyHTML: html
        )
    }

    private static func extractPlainText(from payload: APIMessage.Payload?) -> String? {
        guard let payload else { return nil }
        if let mime = payload.mimeType, mime.lowercased().hasPrefix("text/plain"),
           let b64 = payload.body?.data, let text = decodeBase64URL(b64), !text.isEmpty {
            return text
        }
        if let parts = payload.parts {
            for part in parts {
                if let found = extractPlainText(from: part) { return found }
            }
        }
        return nil
    }

    private static func extractHTML(from payload: APIMessage.Payload?) -> String? {
        guard let payload else { return nil }
        if let mime = payload.mimeType, mime.lowercased().hasPrefix("text/html"),
           let b64 = payload.body?.data, let text = decodeBase64URL(b64), !text.isEmpty {
            return text
        }
        if let parts = payload.parts {
            for part in parts {
                if let found = extractHTML(from: part) { return found }
            }
        }
        // Single-part HTML messages sometimes omit a precise mime on nested parts.
        if let mime = payload.mimeType?.lowercased(), mime.contains("html"),
           let b64 = payload.body?.data, let text = decodeBase64URL(b64), !text.isEmpty {
            return text
        }
        return nil
    }

    private static func extractPlainText(from part: APIMessage.Payload.Part) -> String? {
        if let mime = part.mimeType, mime.lowercased().hasPrefix("text/plain"),
           let b64 = part.body?.data, let text = decodeBase64URL(b64), !text.isEmpty {
            return text
        }
        if let nested = part.parts {
            for p in nested {
                if let found = extractPlainText(from: p) { return found }
            }
        }
        return nil
    }

    private static func extractHTML(from part: APIMessage.Payload.Part) -> String? {
        if let mime = part.mimeType, mime.lowercased().hasPrefix("text/html"),
           let b64 = part.body?.data, let text = decodeBase64URL(b64), !text.isEmpty {
            return text
        }
        if let nested = part.parts {
            for p in nested {
                if let found = extractHTML(from: p) { return found }
            }
        }
        return nil
    }

    private static func decodeBase64URL(_ string: String) -> String? {
        var s = string.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let pad = 4 - s.count % 4
        if pad < 4 { s += String(repeating: "=", count: pad) }
        guard let data = Data(base64Encoded: s) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func throwIfNeeded(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw APIError.http(http.statusCode, text)
        }
    }

    enum APIError: LocalizedError {
        case http(Int, String)
        var errorDescription: String? {
            switch self {
            case .http(let code, let body):
                return "Gmail API error \(code). \(body)"
            }
        }
    }
}

/// Resolves a valid access token for a mailbox (refreshes when expired).
enum GmailTokenStore {
    static func validAccessToken(for mailboxID: UUID) async throws -> String {
        guard var bundle = try MailKeychain.load(mailboxID: mailboxID) else {
            throw TokenError.missing
        }
        let needsRefresh: Bool = {
            guard let expires = bundle.expiresAt else { return false }
            return expires.timeIntervalSinceNow < 60
        }()
        if needsRefresh {
            guard let refresh = bundle.refreshToken else { throw TokenError.missingRefresh }
            let refreshed = try await GmailAuthController.refreshAccessToken(refreshToken: refresh)
            try MailKeychain.save(tokens: refreshed, mailboxID: mailboxID)
            bundle = refreshed
        }
        return bundle.accessToken
    }

    enum TokenError: LocalizedError {
        case missing
        case missingRefresh
        var errorDescription: String? {
            switch self {
            case .missing: return "No stored Gmail credentials. Sign in again."
            case .missingRefresh: return "Session expired. Sign in again."
            }
        }
    }
}
