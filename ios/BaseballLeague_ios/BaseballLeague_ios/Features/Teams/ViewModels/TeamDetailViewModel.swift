import Foundation
import Observation
import BaseballShared

@Observable
final class TeamDetailViewModel {
    var detail: TeamDetailResponse?
    var isLoading = false
    var errorMessage: String?

    private let apiClient: APIClient
    let teamId: UUID

    init(apiClient: APIClient, teamId: UUID) {
        self.apiClient = apiClient
        self.teamId = teamId
    }

    func fetchDetail() async {
        isLoading = true
        errorMessage = nil

        do {
            detail = try await apiClient.request(.team(teamId))
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
