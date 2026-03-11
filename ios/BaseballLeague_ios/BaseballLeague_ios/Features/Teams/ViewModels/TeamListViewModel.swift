import Foundation
import Observation
import BaseballShared

@Observable
final class TeamListViewModel {
    var teams: [TeamResponse] = []
    var isLoading = false
    var errorMessage: String?

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func fetchTeams() async {
        isLoading = true
        errorMessage = nil

        do {
            teams = try await apiClient.request(.teams)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
