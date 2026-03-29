import Foundation
import Observation
import BaseballShared

@Observable
final class GameFormViewModel {
    var homeTeam: TeamResponse?
    var awayTeam: TeamResponse?
    var date = Date()
    var isSaving = false
    var errorMessage: String?
    var didSave = false

    var teams: [TeamResponse] = []
    var isLoadingTeams = false

    var isValid: Bool {
        homeTeam != nil && awayTeam != nil && homeTeam?.id != awayTeam?.id
    }

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func fetchTeams() async {
        isLoadingTeams = true
        do {
            teams = try await apiClient.request(.teams)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingTeams = false
    }

    func save() async {
        guard let homeTeam, let awayTeam, isValid else { return }
        isSaving = true
        errorMessage = nil

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        let request = GameRequest(
            homeTeamId: homeTeam.id,
            awayTeamId: awayTeam.id,
            date: dateFormatter.string(from: date),
            scheduledTime: nil,
            venue: nil
        )

        do {
            let _: GameResponse = try await apiClient.request(.createGame, body: request)
            didSave = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }
}
