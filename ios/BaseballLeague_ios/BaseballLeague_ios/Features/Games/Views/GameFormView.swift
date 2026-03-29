import SwiftUI
import BaseballShared

struct GameFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: GameFormViewModel

    var onSaved: (() -> Void)?

    init(apiClient: APIClient, onSaved: (() -> Void)? = nil) {
        _viewModel = State(initialValue: GameFormViewModel(apiClient: apiClient))
        self.onSaved = onSaved
    }

    var body: some View {
        Form {
            Section("Teams") {
                Picker("Home Team", selection: $viewModel.homeTeam) {
                    Text("Select...").tag(TeamResponse?.none)
                    ForEach(availableHomeTeams, id: \.id) { team in
                        Text(team.name).tag(TeamResponse?.some(team))
                    }
                }

                Picker("Away Team", selection: $viewModel.awayTeam) {
                    Text("Select...").tag(TeamResponse?.none)
                    ForEach(availableAwayTeams, id: \.id) { team in
                        Text(team.name).tag(TeamResponse?.some(team))
                    }
                }

                if let home = viewModel.homeTeam, let away = viewModel.awayTeam, home.id == away.id {
                    Text("Home and away teams must be different.")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }

            Section("Date") {
                DatePicker("Game Date", selection: $viewModel.date, displayedComponents: .date)
            }

            if let error = viewModel.errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }
        }
        .navigationTitle("New Game")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") {
                    Task { await viewModel.save() }
                }
                .disabled(!viewModel.isValid || viewModel.isSaving)
            }
        }
        .disabled(viewModel.isSaving)
        .overlay {
            if viewModel.isLoadingTeams && viewModel.teams.isEmpty {
                ProgressView()
            }
        }
        .task {
            await viewModel.fetchTeams()
        }
        .onChange(of: viewModel.didSave) {
            if viewModel.didSave {
                onSaved?()
                dismiss()
            }
        }
    }

    private var availableHomeTeams: [TeamResponse] {
        viewModel.teams
    }

    private var availableAwayTeams: [TeamResponse] {
        viewModel.teams.filter { $0.id != viewModel.homeTeam?.id }
    }
}
