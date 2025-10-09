import SwiftUI

struct AuthenticatedView: View {
    @Binding var loginState: LoginState
    var loginManager: LoginManager

    var body: some View {
        if case let .LoggedIn(_, claims) = loginState {
            VStack {
                Text("Successfully logged in!").font(.largeTitle)
                    .padding()
                Text("Sub").font(.title)
                Text(claims.sub)
                    .padding(.bottom)
                Text("eID provider").font(.title)
                Text(claims.identityscheme).padding(.bottom)
                Text("Name").font(.title)
                Text(claims.name ?? "").padding(.bottom)
                Spacer()
                Button(action: self.logout) { Text("Log out") }
            }.padding()
        }
    }

    func logout() {
        guard case let .LoggedIn(idToken, claims) = loginState
        else {
            return
        }

        Task {
            loginState = .Loading
            do {
                try await loginManager.logout(
                    presenting: getViewController(),
                    idTokenHint: idToken
                )
            } catch {
                loginState = .NotLoggedIn(
                    errorMessage: error.localizedDescription,
                    previouslyLoggedInAs: claims.uuid
                )
            }
            loginState = .NotLoggedIn(errorMessage: nil, previouslyLoggedInAs: claims.uuid)
        }
    }
}
