import SwiftUI

extension View {
    func getViewController() -> UIViewController {
        let scene = UIApplication.shared.connectedScenes.first as! UIWindowScene
        return scene.keyWindow!.rootViewController!
    }
}

struct UnAuthenticatedView: View {
    @Binding var loginState: LoginState
    var loginManager: LoginManager

    var body: some View {
        if case let .NotLoggedIn(errorMessage, _) = loginState {
            VStack {
                Image(systemName: "lock")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text(errorMessage ?? "")
                    .font(.title)
                Button(action: { self.login(eid: .Mock) }) {
                    Text("Login with Mock")
                }.padding()
                Button(action: { self.login(eid: .MitID) }) {
                    Text("Login with MitID")
                }.padding()
                Button(action: { self.login(eid: .SEBankID) }) {
                    Text("Login with SE BankID")
                }.padding()
                Button(action: { self.login(eid: .NOBankID) }) {
                    Text("Login with NO BankID")
                }.padding()
            }.padding()
                .onAppear(perform: onAppear)
        }
    }

    func onAppear() {
        Task {
            do {
                try await loginManager.prepare()
            } catch {
                self.loginState = .NotLoggedIn(
                    errorMessage: "Error while preparing login manager: \(error.localizedDescription)",
                    previouslyLoggedInAs: nil
                )
            }
        }
    }

    func login(eid: eID) {
        guard case let .NotLoggedIn(
            _, previouslyLoggedInAs
        ) = loginState else {
            return
        }

        Task {
            do {
                loginState = .Loading
                let (idToken, claims) = try await loginManager.login(
                    presenting: self.getViewController(),
                    eid: eid,
                    previouslyLoggedInAs: previouslyLoggedInAs
                )
                loginState = .LoggedIn(idToken: idToken, claims: claims)
            } catch {
                loginState = .NotLoggedIn(
                    errorMessage: "Error during login \(error.localizedDescription)",
                    previouslyLoggedInAs: nil
                )
            }
        }
    }
}
