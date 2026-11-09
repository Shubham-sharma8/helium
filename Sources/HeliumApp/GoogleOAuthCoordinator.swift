import Foundation
import CryptoKit
import AppKit
import AuthenticationServices
import OrbitCore

public enum GoogleOAuthError: LocalizedError, Sendable {
    case invalidAuthorizationURL
    case missingAuthorizationCode
    case stateMismatch
    case tokenExchangeFailed(String)
    case profileFetchFailed

    public var errorDescription: String? {
        switch self {
        case .invalidAuthorizationURL:
            return "Could not construct Google OAuth 2.0 authorization URL."
        case .missingAuthorizationCode:
            return "Google OAuth callback did not include an authorization code."
        case .stateMismatch:
            return "OAuth state parameter mismatch."
        case .tokenExchangeFailed(let detail):
            return "Google OAuth token exchange failed: \(detail)"
        case .profileFetchFailed:
            return "Failed to fetch Google Drive account profile and storage quota."
        }
    }
}

/// Coordinates Google OAuth 2.0 PKCE (`S256`) sign-in using `REVERSED_CLIENT_ID` (`com.googleusercontent.apps.<id>:/oauthredirect`) and `ASWebAuthenticationSession`.
public final class GoogleOAuthCoordinator: NSObject, ASWebAuthenticationPresentationContextProviding, @unchecked Sendable {
    public struct PKCEChallenge: Sendable {
        public let verifier: String
        public let challenge: String

        public init() {
            let raw = ZK.random(32)
            let v = ZK.b64(raw)
            let digest = SHA256.hash(data: Data(v.utf8))
            self.verifier = v
            self.challenge = ZK.b64(Data(digest))
        }
    }

    private var activeSession: ASWebAuthenticationSession?

    public override init() {
        super.init()
    }

    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first ?? ASPresentationAnchor()
    }

    public func reversedClientScheme(clientId: String, configuredReversed: String? = nil) -> String {
        let suffix = ".apps.googleusercontent.com"
        if clientId.hasSuffix(suffix) {
            let prefix = String(clientId.dropLast(suffix.count))
            return "com.googleusercontent.apps.\(prefix)"
        }
        if let configuredReversed, !configuredReversed.isEmpty {
            return configuredReversed
        }
        return "com.cogify.helium"
    }

    public func redirectURI(clientId: String, configuredReversed: String? = nil) -> String {
        "\(reversedClientScheme(clientId: clientId, configuredReversed: configuredReversed)):/oauthredirect"
    }

    public func buildAuthorizationURL(
        clientId: String,
        redirectURI: String,
        pkce: PKCEChallenge,
        state: String
    ) -> URL? {
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile https://www.googleapis.com/auth/drive.file"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "select_account consent"),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state)
        ]
        return components?.url
    }

    @MainActor
    public func signIn(
        clientId: String,
        configuredReversed: String? = nil,
        isFirstAccount: Bool
    ) async throws -> LinkedGoogleAccount {
        let scheme = reversedClientScheme(clientId: clientId, configuredReversed: configuredReversed)
        let redirect = redirectURI(clientId: clientId, configuredReversed: configuredReversed)
        let pkce = PKCEChallenge()
        let expectedState = UUID().uuidString

        guard let authURL = buildAuthorizationURL(
            clientId: clientId,
            redirectURI: redirect,
            pkce: pkce,
            state: expectedState
        ) else {
            throw GoogleOAuthError.invalidAuthorizationURL
        }

        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)

        let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: scheme
            ) { [weak self] url, error in
                self?.activeSession = nil
                if let error {
                    continuation.resume(throwing: error)
                } else if let url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: GoogleOAuthError.missingAuthorizationCode)
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.activeSession = session
            session.start()
        }

        return try await completeCallback(
            callbackURL: callbackURL,
            clientId: clientId,
            redirectURI: redirect,
            pkce: pkce,
            expectedState: expectedState,
            isFirstAccount: isFirstAccount
        )
    }

    public func completeCallback(
        callbackURL: URL,
        clientId: String,
        redirectURI: String,
        pkce: PKCEChallenge,
        expectedState: String,
        isFirstAccount: Bool
    ) async throws -> LinkedGoogleAccount {
        let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
        let items = components?.queryItems ?? []
        if let returnedState = items.first(where: { $0.name == "state" })?.value,
           returnedState != expectedState {
            throw GoogleOAuthError.stateMismatch
        }
        guard let code = items.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
            throw GoogleOAuthError.missingAuthorizationCode
        }

        // Exchange authorization code + PKCE verifier for tokens
        var tokenComponents = URLComponents()
        tokenComponents.scheme = "https"
        tokenComponents.host = "oauth2.googleapis.com"
        tokenComponents.path = "/token"
        guard let tokenURL = tokenComponents.url else {
            throw GoogleOAuthError.invalidAuthorizationURL
        }

        var tokenReq = URLRequest(url: tokenURL, timeoutInterval: 30)
        tokenReq.httpMethod = "POST"
        tokenReq.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "code_verifier", value: pkce.verifier),
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI)
        ]
        tokenReq.httpBody = bodyComponents.percentEncodedQuery?.data(using: .utf8)

        let (tokenData, tokenResp) = try await URLSession.shared.data(for: tokenReq)
        guard let httpToken = tokenResp as? HTTPURLResponse,
              (200..<300).contains(httpToken.statusCode),
              let tokenJSON = try? JSONSerialization.jsonObject(with: tokenData) as? [String: Any],
              let accessToken = tokenJSON["access_token"] as? String else {
            let errBody = String(data: tokenData, encoding: .utf8) ?? "HTTP error"
            throw GoogleOAuthError.tokenExchangeFailed(errBody)
        }
        let refreshToken = (tokenJSON["refresh_token"] as? String) ?? ""

        // Fetch Google Drive user profile + storageQuota
        var aboutComponents = URLComponents()
        aboutComponents.scheme = "https"
        aboutComponents.host = "www.googleapis.com"
        aboutComponents.path = "/drive/v3/about"
        aboutComponents.queryItems = [URLQueryItem(name: "fields", value: "user,storageQuota")]
        guard let aboutURL = aboutComponents.url else {
            throw GoogleOAuthError.profileFetchFailed
        }

        var aboutReq = URLRequest(url: aboutURL, timeoutInterval: 30)
        aboutReq.httpMethod = "GET"
        aboutReq.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (aboutData, aboutResp) = try await URLSession.shared.data(for: aboutReq)
        guard let httpAbout = aboutResp as? HTTPURLResponse,
              (200..<300).contains(httpAbout.statusCode),
              let aboutJSON = try? JSONSerialization.jsonObject(with: aboutData) as? [String: Any] else {
            let errText = String(data: aboutData, encoding: .utf8) ?? "Drive API error"
            throw GoogleOAuthError.tokenExchangeFailed("Google Drive API check failed (\(errText)). Ensure Google Drive API is enabled in Google Cloud Console.")
        }

        let userDict = aboutJSON["user"] as? [String: Any]
        let quotaDict = aboutJSON["storageQuota"] as? [String: Any]

        let email = (userDict?["emailAddress"] as? String) ?? "linked@gmail.com"
        let displayName = (userDict?["displayName"] as? String) ?? email
        let permissionId = (userDict?["permissionId"] as? String) ?? UUID().uuidString.prefix(8).description
        let limitBytes = Int64(quotaDict?["limit"] as? String ?? "") ?? (15 * 1_073_741_824)
        let usageBytes = Int64(quotaDict?["usage"] as? String ?? "") ?? 0

        let rootFolderId = (try? await createOrLocateHeliumRootFolder(accessToken: accessToken)) ?? "root"

        return LinkedGoogleAccount(
            id: "gdrive_\(permissionId)",
            email: email,
            displayName: displayName,
            refreshToken: refreshToken,
            accessToken: accessToken,
            isPrimaryCatalogHost: isFirstAccount,
            quotaLimitBytes: limitBytes,
            quotaUsedBytes: usageBytes,
            heliumUsedBytes: 0,
            rootFolderId: rootFolderId
        )
    }

    private func createOrLocateHeliumRootFolder(accessToken: String) async throws -> String {
        try await URLSessionGoogleDriveTransport().ensureHeliumVaultFolder(accessToken: accessToken)
    }
}
