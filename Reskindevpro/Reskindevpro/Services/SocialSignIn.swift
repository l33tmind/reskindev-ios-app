import Foundation
import AuthenticationServices
import UIKit
import CryptoKit
import FirebaseAuth
import FirebaseCore

// MARK: - Sign in with Apple / Google → same Firebase users as the iOS (Flutter) app and the website
//
// FirebaseAuth's own web-based OAuth flow is iOS-only, and the GoogleSignIn SDK isn't needed:
// Google uses the system browser sheet (ASWebAuthenticationSession) with PKCE and the iOS OAuth
// client from GoogleService-Info.plist, then hands the ID token to Firebase.

enum SocialSignIn {

    // MARK: Apple

    /// Random nonce for Sign in with Apple; its SHA-256 goes in the request, the raw value to Firebase
    static func makeNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String((0..<length).map { _ in charset[Int.random(in: 0..<charset.count)] })
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// Turns the Apple ID result into a Firebase credential
    static func appleCredential(from authorization: ASAuthorization, rawNonce: String) throws -> (AuthCredential, String?) {
        guard let apple = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = apple.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            throw SocialSignInError.missingToken
        }
        let credential = OAuthProvider.appleCredential(withIDToken: idToken, rawNonce: rawNonce, fullName: apple.fullName)
        // Apple only shares the name the first time someone signs in
        let name = apple.fullName.map { PersonNameComponentsFormatter.localizedString(from: $0, style: .default) }
        return (credential, name?.isEmpty == false ? name : nil)
    }

    // MARK: Google

    @MainActor
    static func googleCredential() async throws -> AuthCredential {
        guard let clientID = FirebaseApp.app()?.options.clientID else { throw SocialSignInError.missingClientID }
        // "123-abc.apps.googleusercontent.com" → "com.googleusercontent.apps.123-abc"
        let scheme = clientID.components(separatedBy: ".").reversed().joined(separator: ".")
        let redirectURI = "\(scheme):/oauthredirect"

        let verifier = makeNonce(length: 64)
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncoded
        let state = makeNonce(length: 16)

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            .init(name: "client_id", value: clientID),
            .init(name: "redirect_uri", value: redirectURI),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: "openid email profile"),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state", value: state),
            .init(name: "prompt", value: "select_account"),
        ]

        let callback = try await WebAuth().start(url: components.url!, scheme: scheme)
        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if items.first(where: { $0.name == "error" })?.value != nil { throw SocialSignInError.cancelled }
        guard items.first(where: { $0.name == "state" })?.value == state,
              let code = items.first(where: { $0.name == "code" })?.value else {
            throw SocialSignInError.missingToken
        }

        // Exchange the code for tokens (iOS OAuth clients use PKCE, no client secret)
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var body = URLComponents()
        body.queryItems = [
            .init(name: "code", value: code),
            .init(name: "client_id", value: clientID),
            .init(name: "redirect_uri", value: redirectURI),
            .init(name: "grant_type", value: "authorization_code"),
            .init(name: "code_verifier", value: verifier),
        ]
        request.httpBody = body.percentEncodedQuery?.data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        struct TokenResponse: Decodable {
            let id_token: String?
            let access_token: String?
            let error_description: String?
        }
        let tokens = try JSONDecoder().decode(TokenResponse.self, from: data)
        guard let idToken = tokens.id_token, let accessToken = tokens.access_token else {
            throw SocialSignInError.server(tokens.error_description ?? "Google didn't return a token.")
        }
        return GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
    }
}

/// Async wrapper around the system sign-in browser sheet
@MainActor
private final class WebAuth: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?

    func start(url: URL, scheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callback: .customScheme(scheme)) { callback, error in
                if let callback {
                    continuation.resume(returning: callback)
                } else if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                    continuation.resume(throwing: SocialSignInError.cancelled)
                } else {
                    continuation.resume(throwing: error ?? SocialSignInError.cancelled)
                }
            }
            session.presentationContextProvider = self
            self.session = session
            session.start()
        }
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first { $0.isKeyWindow } ?? ASPresentationAnchor()
        }
    }
}

enum SocialSignInError: LocalizedError {
    case cancelled, missingToken, missingClientID, server(String)

    var errorDescription: String? {
        switch self {
        case .cancelled: "Sign in was cancelled."
        case .missingToken: "Couldn't get a sign-in token. Please try again."
        case .missingClientID: "Google sign-in isn't configured (CLIENT_ID missing in GoogleService-Info.plist)."
        case .server(let message): message
        }
    }
}

private extension Data {
    var base64URLEncoded: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
