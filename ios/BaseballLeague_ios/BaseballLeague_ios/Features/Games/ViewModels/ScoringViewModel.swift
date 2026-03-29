import Foundation
import Observation
import BaseballShared

@Observable
final class ScoringViewModel {
    var game: GameResponse
    var events: [GameEventResponse] = []
    var isLoading = false
    var errorMessage: String?

    // Score entry form state
    var inning: Int = 1
    var inningHalf: InningHalf = .top
    var homeScore: Int = 0
    var awayScore: Int = 0

    private let apiClient: APIClient

    init(apiClient: APIClient, game: GameResponse) {
        self.apiClient = apiClient
        self.game = game
        self.homeScore = game.homeScore
        self.awayScore = game.awayScore
    }

    func loadEvents() async {
        isLoading = true
        errorMessage = nil
        do {
            events = try await apiClient.request(.gameEvents(gameID: game.id))
            syncFromLastScoreEvent()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func postScore() async {
        errorMessage = nil
        let request = GameEventRequest(
            type: .score,
            inning: inning,
            inningHalf: inningHalf,
            homeScore: homeScore,
            awayScore: awayScore,
            comment: nil
        )
        do {
            let event: GameEventResponse = try await apiClient.request(
                .createGameEvent(gameID: game.id),
                body: request
            )
            events.append(event)
            game = GameResponse(
                id: game.id,
                homeTeam: game.homeTeam,
                awayTeam: game.awayTeam,
                date: game.date,
                status: game.status,
                homeScore: homeScore,
                awayScore: awayScore,
                createdAt: game.createdAt
            )
            advanceInning()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateStatus(_ status: GameStatus) async {
        errorMessage = nil
        do {
            game = try await apiClient.request(
                .updateGameStatus(game.id),
                body: GameStatusUpdateRequest(status: status)
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteLastEvent() async {
        guard let lastEvent = events.last else { return }
        errorMessage = nil
        do {
            try await apiClient.requestNoContent(
                .deleteGameEvent(gameID: game.id, eventID: lastEvent.id)
            )
            events.removeLast()
            syncFromLastScoreEvent()
            // Refresh game to get updated scores
            game = try await apiClient.request(.game(game.id))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Private

    private func syncFromLastScoreEvent() {
        if let lastScore = events.last(where: { $0.type == .score }) {
            homeScore = lastScore.homeScore ?? 0
            awayScore = lastScore.awayScore ?? 0
            if let inn = lastScore.inning, let half = lastScore.inningHalf {
                inning = inn
                inningHalf = half
                advanceInning()
            }
        } else {
            homeScore = 0
            awayScore = 0
            inning = 1
            inningHalf = .top
        }
    }

    private func advanceInning() {
        if inningHalf == .top {
            inningHalf = .bottom
        } else {
            inningHalf = .top
            inning += 1
        }
    }
}
