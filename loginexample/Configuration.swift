import Foundation

struct ConfigurationError: Error {
    let message: String
}

/// The client ID of your application. Get it from the criipto dashboard
let _clientId = "[YOUR CLIENT ID]"

/// The URL where your Criipto login is hosted. Can either be a subdomain hosted by Criipto, or your
/// own custom domain.
let _domain = URL(string: "https://[YOUR DOMAIN]")

/// The URI where the users browser is redirected after authentication is complete.
///
/// This should be an HTTPS URI, according to [OAuth 2.0 for Native
/// Apps](https://datatracker.ietf.org/doc/html/rfc8252),
///
/// > Claimed "https" scheme URIs are the preferred redirect choice on iOS 9 and above due to the
/// > ownership proof that is provided by the operating system.
let _redirectUri = _domain?.appendingPathComponent("/ios/callback")

/// The URI to use for app switching in the Danish MitID app. This is the URL that brings control
/// back to your application, after that user has approved in the MitID app.
///
/// This URL _must_ match an associated domain using the `applinks` entitelment, see
/// https://developer.apple.com/documentation/xcode/supporting-associated-domains
/// It must also be registered as a callback URL in your Criipto dashboard.
///
/// Set to nil if you don't need to support MitID app switch
let _appswitchUri = _domain?.appendingPathComponent("/ios/appswitch")

let _useEphemeralBrowserSession = true

struct Configuration {
    let clientId: String
    let domain: URL
    let redirectUri: URL
    let appswitchUri: URL?
    let useEphemeralBrowserSession: Bool

    static func loadConfiguration() throws(ConfigurationError) -> Configuration {
        if _domain == nil {
            throw ConfigurationError(message: "Invalid domain")
        }
        if _redirectUri == nil {
            throw ConfigurationError(message: "Invalid redirect URI")
        }
        if _redirectUri?.scheme != "https" {
            throw ConfigurationError(message: "Redirect URI must be a HTTPS URI")
        }
        if _appswitchUri != nil {
            if _appswitchUri!.scheme != "https" {
                throw ConfigurationError(message: "App switch URI must be a HTTPS URI")
            }
            if ((_appswitchUri!.host!.hasSuffix("criipto.id")) || _appswitchUri!.host!
                .hasSuffix("criipto.io")) && !_appswitchUri!.path
                            .hasPrefix("/ios/")
            {
                throw ConfigurationError(
                    message: "For App switch URI hosted by Criipto, path must begin with /ios"
                )
            }
        }

        return Configuration(
            clientId: _clientId,
            domain: _domain!,
            redirectUri: _redirectUri!,
            appswitchUri: _appswitchUri,
            useEphemeralBrowserSession: _useEphemeralBrowserSession
        )
    }
}
