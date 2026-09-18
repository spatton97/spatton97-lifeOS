import UIKit
import Foundation
import AuthenticationServices

/// Gmail OAuth via `ASWebAuthenticationSession` (read-only scope).
@MainActor
final class GmailAuthController: NSObject, ObservableObject {
    @Published var isAuthenticating = false

    private var session: ASWebAuthenticationSession?
    private let presenter = AuthPresentationContext()

    struct AuthResult {
        let accessToken: String
        let refreshToken: String?
        let expiresIn: TimeInterval?
        let scope: String?
        let tokenType: String?
        let email: String
    }

    func signIn() async throws -> AuthResult {
        guard let clientID = GmailConfig.clientID,
              let redirectURI = GmailConfig.redirectURI,
              let callbackScheme = GmailConfig.reversedClientID else {
            throw AuthError.notConfigured
        }

        isAuthenticating = true
        defer { isAuthenticating = false }

        let code = try await requestAuthorizationCode(
            clientID: clientID,
            redirectURI: redirectURI,
            callbackScheme: callbackScheme
        )
        let tokens = try await exchangeCode(
            code: code,
            clientID: clientID,
            redirectURI: redirectURI
        )
        let email = try await GmailAPI.fetchProfileEmail(accessToken: tokens.accessToken)
        return AuthResult(
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken,
            expiresIn: tokens.expiresIn,
            scope: tokens.scope,
            tokenType: tokens.tokenType,
            email: email
        )
    }

    // MARK: - Auth code

    private func requestAuthorizationCode(
        clientID: String,
        redirectURI: String,
        callbackScheme: String
    ) async throws -> String {
        var comps = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        comps.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: GmailConfig.readonlyScope),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
            URLQueryItem(name: "include_granted_scopes", value: "true")
        ]
        guard let url = comps.url else { throw AuthError.invalidAuthURL }

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let error {
                    let ns = error as NSError
                    if ns.domain == ASWebAuthenticationSessionErrorDomain,
                       ns.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: AuthError.canceled)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                guard let callbackURL,
                      let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                        .queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: AuthError.missingCode)
                    return
                }
                continuation.resume(returning: code)
            }
            session.presentationContextProvider = self.presenter
            session.prefersEphemeralWebBrowserSession = false
            self.session = session
            if !session.start() {
                continuation.resume(throwing: AuthError.sessionFailedToStart)
            }
        }
    }

    // MARK: - Token exchange


    private static func formURLEncoded(_ fields: [String: String]) -> Data? {
        fields
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
    }

    private struct TokenResponse: Decodable {
        let access_token: String
        let expires_in: TimeInterval?
        let refresh_token: String?
        let scope: String?
        let token_type: String?
    }

    private struct TokenPayload {
        let accessToken: String
        let refreshToken: String?
        let expiresIn: TimeInterval?
        let scope: String?
        let tokenType: String?
    }

    private func exchangeCode(code: String, clientID: String, redirectURI: String) async throws -> TokenPayload {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "code": code,
            "client_id": clientID,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code"
        ]
        request.httpBody = Self.formURLEncoded(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw AuthError.tokenExchangeFailed(text)
        }
        let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
        return TokenPayload(
            accessToken: decoded.access_token,
            refreshToken: decoded.refresh_token,
            expiresIn: decoded.expires_in,
            scope: decoded.scope,
            tokenType: decoded.token_type
        )
    }

    /// Refresh an expired access token using the stored refresh token.
    static func refreshAccessToken(refreshToken: String) async throws -> MailKeychain.TokenBundle {
        guard let clientID = GmailConfig.clientID else { throw AuthError.notConfigured }
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "client_id": clientID,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]
        request.httpBody = Self.formURLEncoded(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw AuthError.tokenExchangeFailed(text)
        }
        struct RefreshResponse: Decodable {
            let access_token: String
            let expires_in: TimeInterval?
            let scope: String?
            let token_type: String?
        }
        let decoded = try JSONDecoder().decode(RefreshResponse.self, from: data)
        let expiresAt = decoded.expires_in.map { Date().addingTimeInterval($0) }
        return MailKeychain.TokenBundle(
            accessToken: decoded.access_token,
            refreshToken: refreshToken,
            expiresAt: expiresAt,
            tokenType: decoded.token_type,
            scope: decoded.scope
        )
    }

    enum AuthError: LocalizedError {
        case notConfigured
        case invalidAuthURL
        case canceled
        case missingCode
        case sessionFailedToStart
        case tokenExchangeFailed(String)

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "Gmail Client ID is not configured. See SETUP.md."
            case .invalidAuthURL:
                return "Could not build the Google sign-in URL."
            case .canceled:
                return "Sign-in was canceled."
            case .missingCode:
                return "Google did not return an authorization code."
            case .sessionFailedToStart:
                return "Could not start the sign-in session."
            case .tokenExchangeFailed(let detail):
                return "Token exchange failed. \(detail)"
            }
        }
    }
}

private final class AuthPresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let key = scenes.flatMap(\.windows).first(where: \.isKeyWindow) {
            return key
        }
        if let any = scenes.flatMap(\.windows).first {
            return any
        }
        return ASPresentationAnchor()
    }
}
