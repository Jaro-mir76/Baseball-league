import Vapor
import Fluent
import FluentSQL
import BaseballShared

struct GameScoringService {

    // MARK: - Add Event

    func addEvent(
        gameID: UUID,
        input: GameEventRequest,
        scorerID: UUID,
        on db: any Database
    ) async throws -> GameEvent {
        try validateEventInput(input)

        return try await db.transaction { tx in
            // Lock game row for update
            guard let game = try await lockGame(id: gameID, on: tx) else {
                throw Abort(.notFound, reason: "Game not found")
            }

            guard game.status == .live else {
                throw Abort(.unprocessableEntity, reason: "Game must be live to add events")
            }

            let event = GameEvent(
                gameID: gameID,
                type: input.type,
                inning: input.inning,
                inningHalf: input.inningHalf,
                homeScore: input.homeScore,
                awayScore: input.awayScore,
                comment: input.comment,
                createdByID: scorerID
            )
            try await event.save(on: tx)

            // Update denormalized scores for score events
            if input.type == .score, let homeScore = input.homeScore, let awayScore = input.awayScore {
                game.homeScore = homeScore
                game.awayScore = awayScore
                try await game.save(on: tx)
            }

            return event
        }
    }

    // MARK: - Delete Most Recent Event

    func deleteLastEvent(
        gameID: UUID,
        eventID: UUID,
        on db: any Database
    ) async throws {
        try await db.transaction { tx in
            guard let game = try await lockGame(id: gameID, on: tx) else {
                throw Abort(.notFound, reason: "Game not found")
            }

            guard game.status == .live else {
                throw Abort(.unprocessableEntity, reason: "Game must be live to delete events")
            }

            // Find the most recent event for this game
            guard let lastEvent = try await GameEvent.query(on: tx)
                .filter(\.$game.$id == gameID)
                .sort(\.$createdAt, .descending)
                .first()
            else {
                throw Abort(.notFound, reason: "Event not found")
            }

            guard lastEvent.id == eventID else {
                throw Abort(.conflict, reason: "Only the most recent event can be deleted")
            }

            try await lastEvent.delete(on: tx)

            // Recalculate scores from remaining events
            let lastScoreEvent = try await GameEvent.query(on: tx)
                .filter(\.$game.$id == gameID)
                .filter(\.$type == .score)
                .sort(\.$createdAt, .descending)
                .first()

            game.homeScore = lastScoreEvent?.homeScore ?? 0
            game.awayScore = lastScoreEvent?.awayScore ?? 0
            try await game.save(on: tx)
        }
    }

    // MARK: - Validation

    private func validateEventInput(_ input: GameEventRequest) throws {
        switch input.type {
        case .score:
            guard let inning = input.inning, (1...99).contains(inning) else {
                throw Abort(.badRequest, reason: "Score events require inning (1-99)")
            }
            guard input.inningHalf != nil else {
                throw Abort(.badRequest, reason: "Score events require inningHalf")
            }
            guard let homeScore = input.homeScore, homeScore >= 0 else {
                throw Abort(.badRequest, reason: "Score events require homeScore >= 0")
            }
            guard let awayScore = input.awayScore, awayScore >= 0 else {
                throw Abort(.badRequest, reason: "Score events require awayScore >= 0")
            }
        case .comment:
            guard let comment = input.comment, !comment.trimmingCharacters(in: .whitespaces).isEmpty else {
                throw Abort(.badRequest, reason: "Comment events require a non-empty comment")
            }
        }

        if let comment = input.comment, comment.count > 500 {
            throw Abort(.badRequest, reason: "Comment must be at most 500 characters")
        }
    }

    // MARK: - Helpers

    private func lockGame(id: UUID, on db: any Database) async throws -> Game? {
        if let sqlDB = db as? any SQLDatabase {
            let rows = try await sqlDB.raw("SELECT * FROM games WHERE id = \(bind: id) FOR UPDATE")
                .all()
            guard !rows.isEmpty else { return nil }
        }
        return try await Game.find(id, on: db)
    }
}
