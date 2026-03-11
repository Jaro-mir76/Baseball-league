import Foundation
import Observation

@Observable
final class LoginViewModel {
    var email = ""
    var password = ""
    var errorMessage: String?
    var isLoading = false

    var isValid: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
    }

    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    func login() async {
        guard isValid else { return }
        isLoading = true
        errorMessage = nil

        do {
            try await appState.login(email: email.trimmingCharacters(in: .whitespaces), password: password)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
