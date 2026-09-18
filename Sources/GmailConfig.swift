import Foundation

/// Reads the Google OAuth iOS client ID from Info.plist.
/// Prefers `LifeOSGmailClientID`, falls back to `GIDClientID` (Google Sign-In convention).
enum GmailConfig {
    static let readonlyScope = "https://www.googleapis.com/auth/gmail.readonly"
    static let freeMailboxLimit = 1

    static var clientID: String? {
        let keys = ["LifeOSGmailClientID", "GIDClientID"]
        for key in keys {
            if let value = Bundle.main.object(forInfoDictionaryKey: key) as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty, !trimmed.hasPrefix("$("), trimmed != "YOUR_IOS_CLIENT_ID.apps.googleusercontent.com" {
                    return trimmed
                }
            }
        }
        return nil
    }

    /// Reversed client ID used as the custom URL scheme (standard Google iOS OAuth).
    static var reversedClientID: String? {
        guard let clientID else { return nil }
        // "123-abc.apps.googleusercontent.com" → "com.googleusercontent.apps.123-abc"
        let suffix = ".apps.googleusercontent.com"
        guard clientID.hasSuffix(suffix) else { return nil }
        let prefix = String(clientID.dropLast(suffix.count))
        return "com.googleusercontent.apps.\(prefix)"
    }

    static var redirectURI: String? {
        guard let reversed = reversedClientID else { return nil }
        return "\(reversed):/oauth2redirect/google"
    }

    static var isConfigured: Bool {
        clientID != nil && reversedClientID != nil
    }
}
