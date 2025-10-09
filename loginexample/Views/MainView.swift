import SwiftUI

struct MainView: View {
    @State var loginState = LoginState.NotLoggedIn(errorMessage: nil, previouslyLoggedInAs: nil)
    var loginManager: LoginManager

    init() {
        let configuration = try! Configuration.loadConfiguration()
        loginManager = LoginManager(configuration: configuration)
    }

    var body: some View {
        return VStack {
            switch loginState {
            case .LoggedIn:
                AuthenticatedView(loginState: $loginState, loginManager: loginManager)
            case .NotLoggedIn:
                UnAuthenticatedView(loginState: $loginState, loginManager: loginManager)
            case .Loading:
                LoadingView()
            }
        }
    }
}
