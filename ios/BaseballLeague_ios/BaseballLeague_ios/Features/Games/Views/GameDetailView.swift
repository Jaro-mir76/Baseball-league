import SwiftUI
import BaseballShared

struct GameDetailView: View {
    @Environment(AppState.self) private var appState
    @State private var game: GameResponse?
    @State private var events: [GameEventResponse] = []
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
                        ScoreCard(game: game)
                    }

                    Section("Details") {
                        LabeledContent("Status") {
                            StatusBadge(status: game.status)
                        }
                        LabeledContent("Date", value: String(game.date.prefix(10)))
                    }

                    if game.status != .final, appState.isScorer || appState.isAdmin {
                        Section {
                            NavigationLink("Live Scoring", destination: ScoringView(apiClient: apiClient, game: game))
                        }
                    }

                    if !events.isEmpty {
                        Section("Event Timeline") {
                            ForEach(events, id: \.id) { event in
                                EventRow(event: event)
                            }
                        }
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
            events = try await apiClient.request(.gameEvents(gameID: gameId))
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

}

// MARK: - Score Card

private struct ScoreCard: View {
    let game: GameResponse

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                TeamScoreColumn(
                    name: game.homeTeam.name,
                    shortName: game.homeTeam.shortName,
                    score: game.homeScore,
                    label: "HOME"
                )
                Spacer()
                Text("vs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                TeamScoreColumn(
                    name: game.awayTeam.name,
                    shortName: game.awayTeam.shortName,
                    score: game.awayScore,
                    label: "AWAY"
                )
            }
        }
        .padding(.vertical, 8)
    }
}

private struct TeamScoreColumn: View {
    let name: String
    let shortName: String?
    let score: Int
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(score)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(name)
                .font(.subheadline.bold())
                .multilineTextAlignment(.center)
            if let shortName {
                Text(shortName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
