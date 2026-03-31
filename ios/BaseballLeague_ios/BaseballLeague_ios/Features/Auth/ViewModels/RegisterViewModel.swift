import Foundation
import Observation

@Observable
final class RegisterViewModel {
    var name = ""
    var email = ""
    var password = ""
    var confirmPassword = ""
    var errorMessage: String?
    var isLoading = false

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
        && !email.trimmingCharacters(in: .whitespaces).isEmpty
        && password.count >= 8
        && password == confirmPassword
    }

    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    func register() async {
        guard isValid else { return }
        isLoading = true
        errorMessage = nil

        do {
            try await appState.register(
                email: email.trimmingCharacters(in: .whitespaces),
                password: password,
                name: name.trimmingCharacters(in: .whitespaces)
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
