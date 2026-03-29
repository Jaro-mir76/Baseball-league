import SwiftUI
import BaseballShared

struct GameDetailView: View {
    @State private var game: GameResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let apiClient: APIClient
    private let gameId: UUID

    init(apiClient: APIClient, gameId: UUID) {
        self.apiClient = apiClient
        self.gameId = gameId
    }

    var body: some View {
        Group {
            if let game {
                List {
                    Section {
                        HStack {
                            Text(game.homeTeam.name)
                                .font(.headline)
                            Spacer()
                            Text("\(game.homeScore)")
                                .font(.title2.monospacedDigit().bold())
                        }
                        HStack {
                            Text(game.awayTeam.name)
                                .font(.headline)
                            Spacer()
                            Text("\(game.awayScore)")
                                .font(.title2.monospacedDigit().bold())
                        }
                    }

                    Section {
                        LabeledContent("Status") {
                            StatusBadge(status: game.status)
                        }
                        LabeledContent("Date", value: String(game.date.prefix(10)))
                    }
                }
            } else if isLoading {
                ProgressView()
            } else if let error = errorMessage {
                ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
            }
        }
        .navigationTitle("Game")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await fetchGame()
        }
        .refreshable {
            await fetchGame()
        }
    }

    private func fetchGame() async {
        isLoading = true
        errorMessage = nil
        do {
            game = try await apiClient.request(.game(gameId))
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
