import Foundation
import Observation
import BaseballShared

@Observable
final class GameListViewModel {
    var games: [GameResponse] = []
    var isLoading = false
    var errorMessage: String?
    var totalCount = 0

    // Filters
    var statusFilter: GameStatus?
    var teamFilter: TeamResponse?
    var dateFrom: Date?
    var dateTo: Date?

    private var currentPage = 1
    private let perPage = 20
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    var hasMorePages: Bool {
        games.count < totalCount
    }

    func fetchGames(reset: Bool = true) async {
        if reset {
            currentPage = 1
        }
        isLoading = true
        errorMessage = nil

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        do {
            let response: PaginatedResponse<GameResponse> = try await apiClient.request(
                .games(
                    page: currentPage,
                    perPage: perPage,
                    status: statusFilter?.rawValue,
                    teamId: teamFilter?.id,
                    dateFrom: dateFrom.map { dateFormatter.string(from: $0) },
                    dateTo: dateTo.map { dateFormatter.string(from: $0) }
                )
            )
            if reset {
                games = response.items
            } else {
                games.append(contentsOf: response.items)
            }
            totalCount = response.metadata.total
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func loadNextPage() async {
        guard hasMorePages, !isLoading else { return }
        currentPage += 1
        await fetchGames(reset: false)
    }

    func clearFilters() {
        statusFilter = nil
        teamFilter = nil
        dateFrom = nil
        dateTo = nil
    }
}
