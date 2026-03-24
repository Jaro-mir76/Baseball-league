import Vapor
import Fluent
import BaseballShared

struct GameController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let games = routes.grouped("games")

        games.get(use: index)
        games.get(":gameID", use: show)

        let authenticated = games.grouped(JWTAuthMiddleware())
        authenticated.grouped(RoleMiddleware(.admin, .scorer)).post(use: create)
        authenticated.grouped(RoleMiddleware(.scorer)).patch(":gameID", "status", use: updateStatus)
    }

    // MARK: - GET /games

    @Sendable
    func index(req: Request) async throws -> PaginatedResponse<GameResponse> {
        let page = (req.query[Int.self, at: "page"] ?? 1)
        let perPage = min(req.query[Int.self, at: "perPage"] ?? 20, 50)

        var query = Game.query(on: req.db)
            .join(parent: \.$homeTeam)
            .join(parent: \.$awayTeam)

        if let statusRaw = req.query[String.self, at: "status"],
           let status = GameStatus(rawValue: statusRaw) {
            query = query.filter(\.$status == status)
        }

        if let teamIdStr = req.query[String.self, at: "teamId"],
           let teamId = UUID(uuidString: teamIdStr) {
            query = query.group(.or) { group in
                group.filter(\.$homeTeam.$id == teamId)
                group.filter(\.$awayTeam.$id == teamId)
            }
        }

        let dateFormatter = Self.dateOnlyFormatter()

        if let dateFromStr = req.query[String.self, at: "dateFrom"],
           let dateFrom = dateFormatter.date(from: dateFromStr) {
            query = query.filter(\.$date >= dateFrom)
        }

        if let dateToStr = req.query[String.self, at: "dateTo"],
           let dateTo = dateFormatter.date(from: dateToStr) {
            query = query.filter(\.$date <= dateTo)
        }

        let total = try await query.count()

        let games = try await query
            .sort(\.$date, .descending)
            .range((page - 1) * perPage ..< page * perPage)
            .all()

        let items = games.map { game in
            let home = try! game.joined(Team.self, \Game.$homeTeam)
            let away = try! game.joined(Team.self, \Game.$awayTeam)
            return game.toResponse(homeTeam: home, awayTeam: away)
        }

        return PaginatedResponse(
            items: items,
            metadata: PageMetadata(page: page, perPage: perPage, total: total)
        )
    }

    // MARK: - GET /games/:id

    @Sendable
    func show(req: Request) async throws -> GameResponse {
        guard let game = try await Game.query(on: req.db)
            .filter(\.$id == req.parameters.get("gameID")!)
            .join(parent: \.$homeTeam)
            .join(parent: \.$awayTeam)
            .first()
        else {
            throw Abort(.notFound)
        }

        let home = try game.joined(Team.self, \Game.$homeTeam)
        let away = try game.joined(Team.self, \Game.$awayTeam)
        return game.toResponse(homeTeam: home, awayTeam: away)
    }

    // MARK: - POST /games

    @Sendable
    func create(req: Request) async throws -> Response {
        let input = try req.content.decode(GameRequest.self)

        guard input.homeTeamId != input.awayTeamId else {
            throw Abort(.unprocessableEntity, reason: "Home team and away team must be different")
        }

        guard let homeTeam = try await Team.find(input.homeTeamId, on: req.db) else {
            throw Abort(.notFound, reason: "Home team not found")
        }

        guard let awayTeam = try await Team.find(input.awayTeamId, on: req.db) else {
            throw Abort(.notFound, reason: "Away team not found")
        }

        let dateFormatter = Self.dateOnlyFormatter()
        guard let gameDate = dateFormatter.date(from: input.date) else {
            throw Abort(.badRequest, reason: "Invalid date format. Use YYYY-MM-DD")
        }

        if let venue = input.venue, venue.count > 200 {
            throw Abort(.badRequest, reason: "Venue must be at most 200 characters")
        }

        var scheduledTime: Date?
        if let timeStr = input.scheduledTime {
            let isoFormatter = ISO8601DateFormatter()
            guard let time = isoFormatter.date(from: timeStr) else {
                throw Abort(.badRequest, reason: "Invalid scheduledTime format. Use ISO 8601")
            }
            scheduledTime = time
        }

        let game = Game(
            homeTeamID: input.homeTeamId,
            awayTeamID: input.awayTeamId,
            date: gameDate,
            scheduledTime: scheduledTime,
            venue: input.venue
        )
        try await game.save(on: req.db)

        let response = game.toResponse(homeTeam: homeTeam, awayTeam: awayTeam)
        return try await response.encodeResponse(status: .created, for: req)
    }

    // MARK: - PATCH /games/:id/status

    @Sendable
    func updateStatus(req: Request) async throws -> GameResponse {
        guard let game = try await Game.query(on: req.db)
            .filter(\.$id == req.parameters.get("gameID")!)
            .join(parent: \.$homeTeam)
            .join(parent: \.$awayTeam)
            .first()
        else {
            throw Abort(.notFound)
        }

        let input = try req.content.decode(GameStatusUpdateRequest.self)

        let allowed: Bool = switch (game.status, input.status) {
        case (.scheduled, .live): true
        case (.live, .final):     true
        default:                  false
        }

        guard allowed else {
            throw Abort(.unprocessableEntity, reason: "Cannot transition from \(game.status.rawValue) to \(input.status.rawValue)")
        }

        game.status = input.status
        try await game.save(on: req.db)

        let home = try game.joined(Team.self, \Game.$homeTeam)
        let away = try game.joined(Team.self, \Game.$awayTeam)
        return game.toResponse(homeTeam: home, awayTeam: away)
    }

    // MARK: - Helpers

    private static func dateOnlyFormatter() -> DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }
}
