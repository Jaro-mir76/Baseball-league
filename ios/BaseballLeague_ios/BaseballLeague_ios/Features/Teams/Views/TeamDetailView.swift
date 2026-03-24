import SwiftUI
import BaseballShared

struct TeamDetailView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: TeamDetailViewModel

    private let apiClient: APIClient

    init(apiClient: APIClient, teamId: UUID) {
        self.apiClient = apiClient
        _viewModel = State(initialValue: TeamDetailViewModel(apiClient: apiClient, teamId: teamId))
    }

    var body: some View {
        Group {
            if let detail = viewModel.detail {
                List {
                    Section {
                        LabeledContent("Name", value: detail.name)
                        if let shortName = detail.shortName {
                            LabeledContent("Short Name", value: shortName)
                        }
                    }

                    Section("Roster") {
                        if detail.players.isEmpty {
                            Text("No players on this team.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(detail.players, id: \.id) { player in
                                PlayerRow(player: player)
                            }
                        }
                    }
                }
            } else if viewModel.isLoading {
                ProgressView()
            } else if let error = viewModel.errorMessage {
                ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
            }
        }
        .navigationTitle(viewModel.detail?.name ?? "Team")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if appState.isAdmin {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink(value: "editTeam") {
                        Text("Edit")
                    }
                }
            }
        }
        .task {
            await viewModel.fetchDetail()
        }
        .refreshable {
            await viewModel.fetchDetail()
        }
    }
}

private struct PlayerRow: View {
    let player: PlayerSummary

    var body: some View {
        HStack {
            if let jersey = player.jerseyNumber {
                Text("#\(jersey)")
                    .font(.headline)
                    .monospacedDigit()
                    .frame(width: 40, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(player.firstName) \(player.lastName)")
                    .font(.body)
                if let position = player.position {
                    Text(position)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
