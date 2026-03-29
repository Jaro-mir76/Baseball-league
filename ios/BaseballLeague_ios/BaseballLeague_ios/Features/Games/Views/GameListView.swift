import SwiftUI
import BaseballShared

struct GameListView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: GameListViewModel
    @State private var showingFilters = false
    @State private var showingNewGame = false

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
        _viewModel = State(initialValue: GameListViewModel(apiClient: apiClient))
    }

    var body: some View {
        List {
            ForEach(viewModel.games, id: \.id) { game in
                NavigationLink(value: GameNavigationID(id: game.id)) {
                    GameRow(game: game)
                }
            }

            if viewModel.hasMorePages {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .task {
                        await viewModel.loadNextPage()
                    }
            }
        }
        .overlay {
            if viewModel.isLoading && viewModel.games.isEmpty {
                ProgressView()
            } else if let error = viewModel.errorMessage, viewModel.games.isEmpty {
                ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
            } else if viewModel.games.isEmpty && !viewModel.isLoading {
                ContentUnavailableView("No Games", systemImage: "sportscourt", description: Text("No games have been scheduled yet."))
            }
        }
        .navigationTitle("Games")
        .toolbar {
            if appState.isAdmin || appState.isScorer {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewGame = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    showingFilters = true
                } label: {
                    Label("Filters", systemImage: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
            }
        }
        .sheet(isPresented: $showingNewGame) {
            NavigationStack {
                GameFormView(apiClient: apiClient) {
                    Task { await viewModel.fetchGames() }
                }
            }
        }
        .sheet(isPresented: $showingFilters) {
            NavigationStack {
                GameFilterView(viewModel: viewModel) {
                    Task { await viewModel.fetchGames() }
                }
            }
        }
        .task {
            await viewModel.fetchGames()
        }
        .refreshable {
            await viewModel.fetchGames()
        }
    }

    private var hasActiveFilters: Bool {
        viewModel.statusFilter != nil || viewModel.teamFilter != nil || viewModel.dateFrom != nil || viewModel.dateTo != nil
    }
}

// MARK: - Game Row

private struct GameRow: View {
    let game: GameResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(game.homeTeam.name)
                    .font(.headline)
                Spacer()
                Text("\(game.homeScore)")
                    .font(.title3.monospacedDigit().bold())
            }
            HStack {
                Text(game.awayTeam.name)
                    .font(.headline)
                Spacer()
                Text("\(game.awayScore)")
                    .font(.title3.monospacedDigit().bold())
            }
            HStack {
                StatusBadge(status: game.status)
                Spacer()
                Text(formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var formattedDate: String {
        // date comes as ISO8601 — extract just the date part
        String(game.date.prefix(10))
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: GameStatus

    var body: some View {
        Text(status.rawValue.capitalized)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        switch status {
        case .scheduled: .blue.opacity(0.15)
        case .live:      .green.opacity(0.15)
        case .final:     .secondary.opacity(0.15)
        }
    }

    private var foregroundColor: Color {
        switch status {
        case .scheduled: .blue
        case .live:      .green
        case .final:     .secondary
        }
    }
}

// MARK: - Filter View

private struct GameFilterView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: GameListViewModel
    var onApply: () -> Void

    var body: some View {
        Form {
            Section("Status") {
                Picker("Status", selection: $viewModel.statusFilter) {
                    Text("All").tag(GameStatus?.none)
                    Text("Scheduled").tag(GameStatus?.some(.scheduled))
                    Text("Live").tag(GameStatus?.some(.live))
                    Text("Final").tag(GameStatus?.some(.final))
                }
                .pickerStyle(.segmented)
            }

            Section("Date Range") {
                DatePicker("From", selection: Binding(
                    get: { viewModel.dateFrom ?? .now },
                    set: { viewModel.dateFrom = $0 }
                ), displayedComponents: .date)
                .opacity(viewModel.dateFrom != nil ? 1 : 0.5)

                if viewModel.dateFrom != nil {
                    Button("Clear From Date", role: .destructive) {
                        viewModel.dateFrom = nil
                    }
                    .font(.caption)
                }

                DatePicker("To", selection: Binding(
                    get: { viewModel.dateTo ?? .now },
                    set: { viewModel.dateTo = $0 }
                ), displayedComponents: .date)
                .opacity(viewModel.dateTo != nil ? 1 : 0.5)

                if viewModel.dateTo != nil {
                    Button("Clear To Date", role: .destructive) {
                        viewModel.dateTo = nil
                    }
                    .font(.caption)
                }
            }

            Section {
                Button("Clear All Filters", role: .destructive) {
                    viewModel.clearFilters()
                }
            }
        }
        .navigationTitle("Filters")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Apply") {
                    onApply()
                    dismiss()
                }
            }
        }
    }
}
