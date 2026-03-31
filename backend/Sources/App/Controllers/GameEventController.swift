import Vapor
import Fluent
import BaseballShared

struct GameEventController: RouteCollection {
    let scoringService = GameScoringService()

    func boot(routes: any RoutesBuilder) throws {
        let games = routes.grouped("games")

        let authenticated = games.grouped(JWTAuthMiddleware())
        authenticated.get(":gameID", "events", use: index)

        let scorerOnly = authenticated.grouped(RoleMiddleware(.scorer))
        scorerOnly.post(":gameID", "events", use: create)
        scorerOnly.delete(":gameID", "events", ":eventID", use: delete)
    }

    // MARK: - GET /games/:gameID/events

    @Sendable
    func index(req: Request) async throws -> [GameEventResponse] {
        guard let gameID: UUID = req.parameters.get("gameID") else {
            throw Abort(.badRequest)
        }

        guard let _ = try await Game.find(gameID, on: req.db) else {
            throw Abort(.notFound)
        }

        let events = try await GameEvent.query(on: req.db)
            .filter(\.$game.$id == gameID)
            .with(\.$createdBy)
            .sort(\.$createdAt)
            .all()

        return events.map { $0.toResponse(user: $0.createdBy) }
    }

    // MARK: - POST /games/:gameID/events

    @Sendable
    func create(req: Request) async throws -> Response {
        guard let gameID: UUID = req.parameters.get("gameID") else {
            throw Abort(.badRequest)
        }

        let user = try req.auth.require(AuthenticatedUser.self)
        let input = try req.content.decode(GameEventRequest.self)

        let event = try await scoringService.addEvent(
            gameID: gameID,
            input: input,
            scorerID: user.id,
            on: req.db
        )

        // Load the user for the response
        let dbUser = try await User.find(user.id, on: req.db)
        let response = event.toResponse(user: dbUser!)

        return try await response.encodeResponse(status: .created, for: req)
    }

    // MARK: - DELETE /games/:gameID/events/:eventID

    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        guard let gameID: UUID = req.parameters.get("gameID"),
              let eventID: UUID = req.parameters.get("eventID") else {
            throw Abort(.badRequest)
        }

        try await scoringService.deleteLastEvent(
            gameID: gameID,
            eventID: eventID,
            on: req.db
        )

        return .noContent
    }
}
