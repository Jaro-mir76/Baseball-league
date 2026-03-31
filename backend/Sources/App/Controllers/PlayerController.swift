import Vapor
import Fluent
import BaseballShared

struct PlayerController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let players = routes.grouped("players")

        let adminOnly = players.grouped(JWTAuthMiddleware()).grouped(RoleMiddleware(.admin))
        adminOnly.post(use: create)
        adminOnly.put(":playerID", use: update)
        adminOnly.delete(":playerID", use: delete)

        // GET /teams/:teamID/players — authenticated
        let teams = routes.grouped("teams").grouped(JWTAuthMiddleware())
        teams.get(":teamID", "players", use: indexByTeam)
    }

    // MARK: - GET /teams/:teamID/players

    @Sendable
    func indexByTeam(req: Request) async throws -> [PlayerResponse] {
        guard let teamID: UUID = req.parameters.get("teamID") else {
            throw Abort(.badRequest)
        }

        guard let _ = try await Team.find(teamID, on: req.db) else {
            throw Abort(.notFound)
        }

        let players = try await Player.query(on: req.db)
            .filter(\.$team.$id == teamID)
            .sort(\.$lastName)
            .sort(\.$firstName)
            .all()

        return players.map { $0.toResponse() }
    }

    // MARK: - POST /players

    @Sendable
    func create(req: Request) async throws -> Response {
        let input = try req.content.decode(PlayerRequest.self)

        try validatePlayerInput(firstName: input.firstName, lastName: input.lastName, jerseyNumber: input.jerseyNumber, position: input.position)

        guard let _ = try await Team.find(input.teamId, on: req.db) else {
            throw Abort(.notFound, reason: "Team not found")
        }

        if let jersey = input.jerseyNumber {
            let duplicate = try await Player.query(on: req.db)
                .filter(\.$team.$id == input.teamId)
                .filter(\.$jerseyNumber == jersey)
                .first()
            if duplicate != nil {
                throw Abort(.conflict, reason: "Jersey number \(jersey) is already taken on this team")
            }
        }

        let player = Player(
            firstName: input.firstName,
            lastName: input.lastName,
            jerseyNumber: input.jerseyNumber,
            position: input.position,
            teamID: input.teamId
        )
        try await player.save(on: req.db)

        return try await player.toResponse().encodeResponse(status: .created, for: req)
    }

    // MARK: - PUT /players/:id

    @Sendable
    func update(req: Request) async throws -> PlayerResponse {
        guard let player = try await Player.find(req.parameters.get("playerID"), on: req.db) else {
            throw Abort(.notFound)
        }

        let input = try req.content.decode(PlayerUpdateRequest.self)

        try validatePlayerInput(firstName: input.firstName, lastName: input.lastName, jerseyNumber: input.jerseyNumber, position: input.position)

        if let jersey = input.jerseyNumber {
            let duplicate = try await Player.query(on: req.db)
                .filter(\.$team.$id == player.$team.id)
                .filter(\.$jerseyNumber == jersey)
                .filter(\.$id != player.id ?? UUID())
                .first()
            if duplicate != nil {
                throw Abort(.conflict, reason: "Jersey number \(jersey) is already taken on this team")
            }
        }

        player.firstName = input.firstName
        player.lastName = input.lastName
        player.jerseyNumber = input.jerseyNumber
        player.position = input.position
        try await player.save(on: req.db)

        return player.toResponse()
    }

    // MARK: - DELETE /players/:id

    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        guard let player = try await Player.find(req.parameters.get("playerID"), on: req.db) else {
            throw Abort(.notFound)
        }

        try await player.delete(on: req.db)
        return .noContent
    }

    // MARK: - Validation

    private func validatePlayerInput(firstName: String, lastName: String, jerseyNumber: Int?, position: String?) throws {
        guard !firstName.trimmingCharacters(in: .whitespaces).isEmpty, firstName.count <= 50 else {
            throw Abort(.badRequest, reason: "firstName must be 1-50 characters")
        }
        guard !lastName.trimmingCharacters(in: .whitespaces).isEmpty, lastName.count <= 50 else {
            throw Abort(.badRequest, reason: "lastName must be 1-50 characters")
        }
        if let jersey = jerseyNumber, !(0...99).contains(jersey) {
            throw Abort(.badRequest, reason: "jerseyNumber must be 0-99")
        }
        if let pos = position, pos.count > 10 {
            throw Abort(.badRequest, reason: "position must be at most 10 characters")
        }
    }
}
