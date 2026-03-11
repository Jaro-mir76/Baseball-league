import Vapor
import Fluent
import BaseballShared

struct TeamController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let teams = routes.grouped("teams")

        teams.get(use: index)
        teams.get(":teamID", use: show)

        let adminOnly = teams.grouped(JWTAuthMiddleware()).grouped(RoleMiddleware(.admin))
        adminOnly.post(use: create)
        adminOnly.put(":teamID", use: update)
        adminOnly.delete(":teamID", use: delete)
    }

    // MARK: - GET /teams

    @Sendable
    func index(req: Request) async throws -> [TeamResponse] {
        var query = Team.query(on: req.db)

        if let search = req.query[String.self, at: "search"], !search.isEmpty {
            query = query.filter(\.$name, .custom("ILIKE"), "%\(search)%")
        }

        let teams = try await query.sort(\.$name).all()
        return teams.map { $0.toResponse() }
    }

    // MARK: - GET /teams/:id

    @Sendable
    func show(req: Request) async throws -> TeamDetailResponse {
        guard let team = try await Team.find(req.parameters.get("teamID"), on: req.db) else {
            throw Abort(.notFound)
        }

        // Players will be loaded in Phase 3
        return TeamDetailResponse(
            id: team.id ?? UUID(),
            name: team.name,
            shortName: team.shortName,
            players: [],
            createdAt: team.createdAt.map { ISO8601DateFormatter().string(from: $0) } ?? ""
        )
    }

    // MARK: - POST /teams

    @Sendable
    func create(req: Request) async throws -> Response {
        let input = try req.content.decode(TeamRequest.self)

        let existing = try await Team.query(on: req.db)
            .filter(\.$name == input.name)
            .withDeleted()
            .first()
        if existing != nil {
            throw Abort(.conflict, reason: "Team name already exists")
        }

        let team = Team(name: input.name, shortName: input.shortName)
        try await team.save(on: req.db)

        return try await team.toResponse().encodeResponse(status: .created, for: req)
    }

    // MARK: - PUT /teams/:id

    @Sendable
    func update(req: Request) async throws -> TeamResponse {
        guard let team = try await Team.find(req.parameters.get("teamID"), on: req.db) else {
            throw Abort(.notFound)
        }

        let input = try req.content.decode(TeamRequest.self)

        // Check name uniqueness (excluding current team)
        let duplicate = try await Team.query(on: req.db)
            .filter(\.$name == input.name)
            .filter(\.$id != team.id ?? UUID())
            .withDeleted()
            .first()
        if duplicate != nil {
            throw Abort(.conflict, reason: "Team name already exists")
        }

        team.name = input.name
        team.shortName = input.shortName
        try await team.save(on: req.db)

        return team.toResponse()
    }

    // MARK: - DELETE /teams/:id

    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        guard let team = try await Team.find(req.parameters.get("teamID"), on: req.db) else {
            throw Abort(.notFound)
        }

        // Phase 4 will add check for scheduled/live games
        try await team.delete(on: req.db)
        return .noContent
    }
}
