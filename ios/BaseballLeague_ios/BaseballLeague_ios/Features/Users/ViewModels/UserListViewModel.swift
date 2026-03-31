import Foundation
import Observation
import BaseballShared

@Observable
final class UserListViewModel {
    var users: [UserResponse] = []
    var isLoading = false
    var errorMessage: String?

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func loadUsers() async {
        isLoading = true
        errorMessage = nil
        do {
            users = try await apiClient.request(.users)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func deleteUser(_ id: UUID) async {
        do {
            try await apiClient.requestNoContent(.deleteUser(id))
            users.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
