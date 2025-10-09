enum LoginState {
    case LoggedIn(idToken: String, claims: IDTokenClaims)
    case NotLoggedIn(errorMessage: String?, previouslyLoggedInAs: String?)
    case Loading
}
