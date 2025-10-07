# criipto-verify-ios-example

This project shows how to integrate Criipto Verify login into your iOS app. Specifically, the application acts as a [_public client_](https://docs.criipto.com/verify/getting-started/glossary/#public-clients), meaning it does not use a client secret, but instead employs [PKCE](https://docs.criipto.com/verify/getting-started/glossary/#pkce-proof-key-for-code-exchange) to ensure that a malicious actor cannot intercept the authorization code.

This project is built using Xcode 26, Swift 6 and SwiftUI. It builds on top of the [AppAuth library](https://github.com/openid/AppAuth-iOS), which is maintained by the OpenID foundation. It runs on iOS 17.4 and newer, because some features in `ASWebAuthenticationSession` are only available from that version. As of June 4th, 2025, 91% of all devices are on iOS 17, [according to Apple](https://developer.apple.com/support/app-store/).

In addition to the basic OIDC flow, this project also shows how to implement [app switching](https://docs.criipto.com/verify/guides/appswitch/) for the Danish MitID app.

> [!IMPORTANT]
> This example makes use of [associated domains](https://developer.apple.com/documentation/xcode/supporting-associated-domains), which require a paid Apple developer account.

## Code structure

- `LoginManager` encapsulates the majority of the OIDC logic. This class is responsible for interacting with the `AppAuth` library.
- `ASWebAuthenticationUserAgent` implements the user agent (the thing that shows the login UI to the user).
- `Configuration` contains static configuration values.
- The `Views` folder contains three simple SwiftUI views, one for showing the login buttons, one for showing the details of a logged in user, and one for showing a loading state.

## Configuration

This assumes that you will be using your Criipto domain to host your [redirect URL](https://docs.criipto.com/verify/getting-started/glossary/#redirect-uri-callback-url). If you wish to use a separate domain, see the Apple developer documentation on [Universal Links](https://developer.apple.com/documentation/xcode/supporting-associated-domains) for how to set it up.

- Configure a new application at https://dashboard.criipto.com/. You should use a separate application for each platform you intend to deploy on.
  - In the OpenID Connect section, ensure that 'Require PKCE' is checked.
  - Add `https://[YOUR CRIIPTO DOMAIN]/ios/callback` as a callback URL.
  - Add `https://[YOUR CRIIPTO DOMAIN]/ios/appswitch` as a callback URL, if you need to support appswitch as well.
  - In the Native/Mobile section, add your app bundle ID, and your team ID (available from https://developer.apple.com/account)
- Update the `Configuration.swift` file with your client ID and domain.
  - Optionally also update the value of `useEphemeralBrowserSession`, see [Ephemeral browser sessions](#ephemeral-browser-sessions)
- In the XCode project settings, under the 'Signing & Capabilities' tab, add an associated domain: `webcredentials:[YOUR CRIIPTO DOMAIN]`
  - If you need to support app switching, add `applinks:[YOUR CRIIPTO DOMAIN]` as well

### App switching

[App switching](https://docs.criipto.com/verify/guides/appswitch/) refers to the process of switching from your app to the verification app of the eID provider, and switching back to your app, after the user has completed the verification process.

Currently, this is only supported for the Danish MitID app.

The initial switch to the MitID app is outside of your control. The MitID Core Client will present a button to the user, allowing them to switch to the MitID app, regardless of how you initiate the login. In order for the MitID app to switch back to your app, you must set the `appswitch:ios` and `appswitch:resumeUrl` login hints. See `LoginManager.swift` for details.
Additionally, you must register a [Universal Link](https://developer.apple.com/documentation/xcode/supporting-associated-domains) using the `applinks` entitlement.

Once the user approves the login in the MitID app, the MitID app will open the universal link you specified as `resumeUrl`. This link _does not_ contain any OIDC parameters, it only serves to return control to your app. This means that you do not need to add a universal link handler.
Once control returns to your app, the authorization flow continues in the browser, which is redirected to the redirect URL.

### Ephemeral browser sessions

The web view used to display the login page to the user allows us to choose between using an ephemeral or a shared browser session.

- **An ephemeral session** Shares no cookies with the user's browser, so the user may be required to enter their login again, if you are re-authenticating them.
- **A shared session** Shares cookies with the user's browser, so login details may be remembered between logins. However, the user is presented with the following dialog each time they want to log in:

<img width="304" height="212" src="https://github.com/user-attachments/assets/e4735591-ffe2-41bb-a725-b08e2490ba9b" />

It is up to you to decide which flow is better, based on the UX requirements of your application.

Danish MitID supports a [re-authentication flow](https://docs.criipto.com/verify/e-ids/danish-mitid/#reauthentication), so you do not need to rely on shared sessions if you need to re-authenticate the user with MitID.

---

The next two sections explain the reasoning behind choosing a `ASWebAuthenticationSession` and HTTPS redirect URLs, and the alternatives considered.

> [!IMPORTANT]
> TL;DR? - This project uses `ASWebAuthenticationSession`, and an HTTPS redirect URL with the `webcredentials` entitlement. Unless you have an excellent reason not to, you should too!

### Web View

You will want to display the login screens using some form of web view (what `AppAuth` calls an `OIDExternalUserAgent`). You have two choices, [`ASWebAuthenticationSession`](https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession) and [`SFSafariViewController`](https://developer.apple.com/documentation/safariservices/sfsafariviewcontroller). In almost all cases you will want to use `ASWebAuthenticationSession`, since it is newer, and more tailored towards authenticating a user, whereas `SFSafariViewController` is a general-purpose Safari instance.

The main benefit of `ASWebAuthenticationSession` is, that it does not depend on a universal link to make it back to your application, in order to obtain the token. Instead, you specify the redirect URL, and once the browser is redirected to this URL, a continuation is invoked with the redirect URL, allowing you to complete the OIDC login.
Contrast this with `SFSafariViewController`, which requires your application to react to universal links (using [`onOpenURL`](<https://developer.apple.com/documentation/swiftui/view/onopenurl(perform:)>) in SwiftUI, or responding to a [`NSUserActivityTypeBrowsingWeb`](https://developer.apple.com/documentation/xcode/supporting-universal-links-in-your-app) activity in UIKit), and resume the OIDC flow from there.
While the difference in lines of code is small, the `ASWebAuthenticationSession` flow is easier to follow, since you complete the OIDC flow in the same place where you instantiate the `ASWebAuthenticationSession`, instead of storing a reference to the `OIDExternalUserAgentSession` and resuming it later. On top of that, universal links are only triggered when the user clicks on them, _not_ on redirect.

### Redirect URL

The redirect URL is the location where the user's browser is redirected after authentication is complete. This can either be an HTTPS URL, or a URL using a custom scheme. According to the [OAuth 2.0 for Native Apps](https://datatracker.ietf.org/doc/html/rfc8252) best practices document:

> Claimed "https" scheme URIs are the preferred redirect choice on iOS 9 and above due to the ownership proof that is provided by the operating system.

Using an HTTPS redirect URI prevents a malicious actor from impersonating your app, by using your client ID and redirect URI to start a login flow from their own app. This is because HTTPS URIs must be claimed before they can be used.

In older versions of iOS, using HTTPS redirect URLs had issues, since it relied on universal links, which are [inherently brittle](https://stackoverflow.com/questions/32751225/ios-universal-links-are-not-opening-in-app). For example, universal links require the user to click a button, it is not enough to redirect them. However, this limitation no longer applies, since `ASWebAuthenticationSession` does not rely on universal links.
