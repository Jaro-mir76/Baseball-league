import Foundation
import Observation
import BaseballShared

@Observable
final class UserFormViewModel {
    var name = ""
    var email = ""
    var password = ""
    var selectedRole: UserRole = .viewer
    var isSaving = false
    var errorMessage: String?
    var didSave = false

    let editingUser: UserResponse?
    var isEditing: Bool { editingUser != nil }

    var isValid: Bool {
        let nameOk = !name.trimmingCharacters(in: .whitespaces).isEmpty
        if isEditing {
            return nameOk
        }
        return nameOk
            && !email.trimmingCharacters(in: .whitespaces).isEmpty
            && password.count >= 8
    }

    private let apiClient: APIClient

    init(apiClient: APIClient, user: UserResponse? = nil) {
        self.apiClient = apiClient
        self.editingUser = user
        if let user {
            self.name = user.name
            self.email = user.email
            self.selectedRole = user.role
        }
    }

    func save() async {
        guard isValid else { return }
        isSaving = true
        errorMessage = nil

        do {
            if let user = editingUser {
                let body = UserUpdateRequest(
                    name: name.trimmingCharacters(in: .whitespaces),
                    role: selectedRole
                )
                let _: UserResponse = try await apiClient.request(.updateUser(user.id), body: body)
            } else {
                let body = RegisterRequest(
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password,
                    name: name.trimmingCharacters(in: .whitespaces),
                    role: selectedRole
                )
                let _: UserResponse = try await apiClient.request(.register, body: body)
            }
            didSave = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }
}
