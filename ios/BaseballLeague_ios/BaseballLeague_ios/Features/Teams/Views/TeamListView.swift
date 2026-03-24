import SwiftUI
import BaseballShared

struct TeamListView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: TeamListViewModel
    @State private var showingNewTeam = false

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
        _viewModel = State(initialValue: TeamListViewModel(apiClient: apiClient))
    }

    var body: some View {
        List {
            ForEach(viewModel.teams, id: \.id) { team in
                NavigationLink(value: team.id) {
                    TeamRow(team: team)
                }
            }
        }
        .overlay {
            if viewModel.isLoading && viewModel.teams.isEmpty {
                ProgressView()
            } else if let error = viewModel.errorMessage, viewModel.teams.isEmpty {
                ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
            } else if viewModel.teams.isEmpty && !viewModel.isLoading {
                ContentUnavailableView("No Teams", systemImage: "person.3", description: Text("No teams have been created yet."))
            }
        }
        .navigationTitle("Teams")
        .toolbar {
            if appState.isAdmin {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewTeam = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingNewTeam) {
            NavigationStack {
                TeamFormView(apiClient: apiClient) {
                    Task { await viewModel.fetchTeams() }
                }
            }
        }
        .task {
            await viewModel.fetchTeams()
        }
        .refreshable {
            await viewModel.fetchTeams()
        }
    }
}

private struct TeamRow: View {
    let team: TeamResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(team.name)
                    .font(.headline)
                if let shortName = team.shortName {
                    Text(shortName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.fill)
                        .clipShape(Capsule())
                }
            }
            Text("\(team.playerCount) players")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
