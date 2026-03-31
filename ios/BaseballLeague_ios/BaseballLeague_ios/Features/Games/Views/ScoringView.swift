import SwiftUI
import BaseballShared

struct ScoringView: View {
    @State private var viewModel: ScoringViewModel

    init(apiClient: APIClient, game: GameResponse) {
        _viewModel = State(initialValue: ScoringViewModel(apiClient: apiClient, game: game))
    }

    var body: some View {
        List {
            Section {
                ScoreBoardSection(game: viewModel.game)
            }

            if viewModel.game.status == .live {
                Section("Record Score") {
                    InningPicker(inning: $viewModel.inning, inningHalf: $viewModel.inningHalf)

                    ScoreStepper(label: "Home (\(viewModel.game.homeTeam.shortName ?? "HOME"))",
                                 score: $viewModel.homeScore)
                    ScoreStepper(label: "Away (\(viewModel.game.awayTeam.shortName ?? "AWAY"))",
                                 score: $viewModel.awayScore)

                    Button("Post Score") {
                        Task { await viewModel.postScore() }
                    }
                    .bold()
                }
            }

            if viewModel.game.status == .live {
                Section("Comment") {
                    CommentEntryView { text in
                        await viewModel.postComment(text)
                    }
                }
            }

            if viewModel.game.status == .live {
                Section {
                    Button("End Game", role: .destructive) {
                        Task { await viewModel.updateStatus(.final) }
                    }
                }
            }

            if viewModel.game.status == .scheduled {
                Section {
                    Button("Start Game") {
                        Task { await viewModel.updateStatus(.live) }
                    }
                    .bold()
                }
            }

            if !viewModel.events.isEmpty {
                Section("Event Timeline") {
                    ForEach(viewModel.events, id: \.id) { event in
                        EventRow(event: event)
                    }
                }
            }
        }
        .navigationTitle("Live Scoring")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadEvents()
        }
        .refreshable {
            await viewModel.loadEvents()
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

// MARK: - Score Board

private struct ScoreBoardSection: View {
    let game: GameResponse

    var body: some View {
        HStack {
            VStack(spacing: 4) {
                Text("HOME")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(game.homeScore)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(game.homeTeam.name)
                    .font(.subheadline.bold())
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)

            StatusBadge(status: game.status)

            VStack(spacing: 4) {
                Text("AWAY")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(game.awayScore)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(game.awayTeam.name)
                    .font(.subheadline.bold())
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Inning Picker

private struct InningPicker: View {
    @Binding var inning: Int
    @Binding var inningHalf: InningHalf

    var body: some View {
        HStack {
            Text("Inning")
            Spacer()
            Picker("Half", selection: $inningHalf) {
                Text("Top").tag(InningHalf.top)
                Text("Bot").tag(InningHalf.bottom)
            }
            .pickerStyle(.segmented)
            .frame(width: 120)

            Stepper("\(inning)", value: $inning, in: 1...99)
                .frame(width: 120)
        }
    }
}

// MARK: - Score Stepper

private struct ScoreStepper: View {
    let label: String
    @Binding var score: Int

    var body: some View {
        Stepper("\(label): \(score)", value: $score, in: 0...999)
    }
}

// MARK: - Event Row

private struct EventRow: View {
    let event: GameEventResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch event.type {
            case .score:
                HStack {
                    if let inning = event.inning, let half = event.inningHalf {
                        Text(half == .top ? "\u{25B3}" : "\u{25BD}")
                        Text("Inning \(inning)")
                            .font(.subheadline.bold())
                    }
                    Spacer()
                    if let home = event.homeScore, let away = event.awayScore {
                        Text("\(home) - \(away)")
                            .font(.subheadline.bold())
                            .monospacedDigit()
                    }
                }
            case .comment:
                if let comment = event.comment {
                    Text(comment)
                        .font(.subheadline)
                }
            }
            Text(event.createdBy.name)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
