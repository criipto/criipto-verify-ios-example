@preconcurrency import AppAuth
@preconcurrency import AppAuthCore
import JWTKit
import os
import SwiftUI

enum eID: String {
    case MitID = "urn:grn:authn:dk:mitid:substantial"
    case SEBankID = "urn:grn:authn:se:bankid"
    case NOBankID = "urn:grn:authn:no:bankid:substantial"
    case Mock = "urn:grn:authn:mock"
}

struct IDTokenClaims: JWTPayload {
    var sub: String
    var name: String?
    var identityscheme: String
    var uuid: String?
    var exp: ExpirationClaim

    func verify(using _: some JWTAlgorithm) throws {
        try exp.verifyNotExpired()
    }
}

class LoginManager: @unchecked Sendable {
    let logger = Logger(subsystem: "com.criipto.loginexample", category: "LoginManager")
    let configuration: Configuration

    var prepared = false
    /// A JSON Web Key Set (JWKS), containing the public keys used to verify that the obtained JWT
    /// was actually issued by Criipto
    var criiptoJwks: JWTKeyCollection?
    var criiptoServiceConfiguration: OIDServiceConfiguration?

    init(configuration: Configuration) {
        self.configuration = configuration
    }

    private var currentAuthorizationSession: OIDExternalUserAgentSession?
    func login(presenting: UIViewController, eid: eID,
               previouslyLoggedInAs: String?) async throws -> (String, IDTokenClaims)
    {
        try await ensurePrepared()

        Task {
            @MainActor in
            self.currentAuthorizationSession?.cancel()
        }

        logger.log("Starting login flow for \(eid.rawValue)")

        var loginHints = [String]()
        var extraParams = [String: String]()

        extraParams["acr_values"] = eid.rawValue

        loginHints.append("appswitch:ios")
        if configuration.appswitchUri != nil {
            loginHints.append("appswitch:resumeUrl:\(configuration.appswitchUri!)")
        }
        if eid == .MitID, previouslyLoggedInAs != nil {
            // If a user has been logged in before, MitID supports skipping the username input
            // step.
            loginHints.append("uuid:\(previouslyLoggedInAs!)")
        }

        extraParams["login_hint"] = loginHints.joined(separator: " ")

        let request = OIDAuthorizationRequest(configuration: criiptoServiceConfiguration!,
                                              clientId: configuration.clientId,
                                              clientSecret: nil,
                                              scopes: [OIDScopeOpenID],
                                              redirectURL: configuration.redirectUri,
                                              responseType: OIDResponseTypeCode,
                                              additionalParameters: extraParams)

        logger.debug(
            "Starting external authentication flow with URL: \(request.authorizationRequestURL())"
        )

        let authState = try await withCheckedThrowingContinuation {
            continuation in
            Task {
                // This is the code that presents the browser to the user, so it needs to run on the
                // main thread
                @MainActor in
                self.currentAuthorizationSession =
                    OIDAuthState.authState(
                        byPresenting: request,
                        externalUserAgent: ASWebAuthenticationUserAgent(
                            presenting: presenting,
                            redirectUri: configuration.redirectUri,
                            useEphemeralBrowserSession: configuration.useEphemeralBrowserSession
                        )
                    ) {
                        authState, error in
                        if let authState = authState {
                            continuation.resume(returning: authState)
                        } else {
                            continuation.resume(throwing: error!)
                        }
                    }
            }
        }
        currentAuthorizationSession = nil

        let idToken = authState.lastTokenResponse!.idToken!
        logger.debug("Got ID Token: \(idToken)")
        let claims = try await criiptoJwks!.verify(
            idToken,
            as: IDTokenClaims.self
        )

        return (idToken, claims)
    }

    func logout(presenting: UIViewController,
                idTokenHint: String) async throws -> OIDEndSessionResponse
    {
        try await ensurePrepared()

        let request = OIDEndSessionRequest(
            configuration: criiptoServiceConfiguration!,
            idTokenHint: idTokenHint,
            postLogoutRedirectURL: configuration.redirectUri,
            additionalParameters: nil
        )

        let response = try await withCheckedThrowingContinuation {
            continuation in
            Task {
                @MainActor in
                self.currentAuthorizationSession = OIDAuthorizationService.present(
                    request,
                    externalUserAgent: ASWebAuthenticationUserAgent(
                        presenting: presenting,
                        redirectUri: configuration.redirectUri,
                        useEphemeralBrowserSession: true
                    )
                ) {
                    response, error in
                    if let response = response {
                        continuation.resume(returning: response)
                    } else if error != nil {
                        continuation.resume(throwing: error!)
                    }
                }
            }
        }
        currentAuthorizationSession = nil
        return response
    }

    /// Prepare the login manager by loading Criipto OIDC configuration and JWK keyset.
    /// This should be called when you present the 'Login with X' button to your user, so that the
    /// required configuration is already loaded when a user clicks the button.
    func prepare() async throws {
        try await loadCriiptoOIDCConfiguration()
        try await loadCriiptoJwks()
        prepared = true
    }

    /// A helper method, used to ensure that the login manager is in the expected state when a login
    /// or logout starts. Ideally, the login manager should be prepared as soon as the button to log
    /// in is shown, but if the developer forgot, or the end-user started the flow before the
    /// prepare operation completed, we call prepare here.
    private func ensurePrepared() async throws {
        if !prepared {
            logger
                .debug(
                    "LoginManager was not in prepared state when calling login / logout. This can happen either if you forget to call `prepare()` from your own code, if the call to `prepare()` failed, or if the user started a session before your call to `prepare()` completed."
                )
            try await prepare()
        }
    }

    private func loadCriiptoJwks() async throws {
        guard criiptoJwks == nil else { return }

        let (data, _) = try await URLSession.shared
            .data(from: configuration.domain.appendingPathComponent("/.well-known/jwks"))
        criiptoJwks = try await JWTKeyCollection().add(jwksJSON: String(
            data: data,
            encoding: .utf8
        )!)
    }

    private func loadCriiptoOIDCConfiguration() async throws {
        guard criiptoServiceConfiguration == nil else { return }

        criiptoServiceConfiguration =
            try await withCheckedThrowingContinuation {
                continuation in
                OIDAuthorizationService
                    .discoverConfiguration(forIssuer: configuration.domain) {
                        configuration, error in
                        if error != nil {
                            continuation.resume(throwing: error!)
                        } else if configuration != nil {
                            continuation.resume(returning: configuration!)
                        }
                    }
            }
    }
}
