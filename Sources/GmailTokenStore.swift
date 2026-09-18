import Foundation
import SwiftData

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
            do {
                let refreshed = try await GmailAuthController.refreshAccessToken(refreshToken: refresh)
                try MailKeychain.save(tokens: refreshed, mailboxID: mailboxID)
                bundle = refreshed
            } catch {
                throw TokenError.refreshFailed(error.localizedDescription)
            }
        }
        return bundle.accessToken
    }

    enum TokenError: LocalizedError {
        case missing
        case missingRefresh
        case refreshFailed(String)
        var errorDescription: String? {
            switch self {
            case .missing: return "No stored Gmail credentials. Sign in again."
            case .missingRefresh: return "Session expired. Sign in again."
            case .refreshFailed(let detail): return "Session expired. Sign in again. \(detail)"
            }
        }
    }
}

/// Shared mailbox session helper: valid token or disconnect on auth failure.
enum MailSession {
    /// Returns a valid access token. On `GmailTokenStore.TokenError` / failed refresh,
    /// clears Keychain for that mailbox UUID and deletes the `MailMailbox` row so UI shows Connect.
    @MainActor
    static func ensureValidAccessToken(for mailboxID: UUID, in modelContext: ModelContext) async throws -> String {
        do {
            return try await GmailTokenStore.validAccessToken(for: mailboxID)
        } catch let error as GmailTokenStore.TokenError {
            disconnect(mailboxID: mailboxID, in: modelContext)
            throw error
        }
    }

    @MainActor
    static func disconnect(mailboxID: UUID, in modelContext: ModelContext) {
        MailKeychain.delete(mailboxID: mailboxID)
        let target = mailboxID
        let descriptor = FetchDescriptor<MailMailbox>(predicate: #Predicate { $0.id == target })
        if let boxes = try? modelContext.fetch(descriptor) {
            for box in boxes {
                modelContext.delete(box)
            }
            try? modelContext.save()
        }
    }
}
