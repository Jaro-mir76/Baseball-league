import Foundation

nonisolated enum Endpoint: Sendable {
    // MARK: - Auth
    case login
    case signup
    case register
    case refresh
    case logout

    // MARK: - Users
    case users
    case updateUser(UUID)
    case deleteUser(UUID)

    // MARK: - Teams
    case teams
    case team(UUID)
    case createTeam
    case updateTeam(UUID)
    case deleteTeam(UUID)

    // MARK: - Players
    case teamPlayers(UUID)
    case createPlayer
    case updatePlayer(UUID)
    case deletePlayer(UUID)

    // MARK: - Games
    case games(page: Int, perPage: Int, status: String?, teamId: UUID?, dateFrom: String?, dateTo: String?)
    case game(UUID)
    case createGame
    case updateGameStatus(UUID)

    // MARK: - Game Events
    case gameEvents(gameID: UUID)
    case createGameEvent(gameID: UUID)
    case deleteGameEvent(gameID: UUID, eventID: UUID)

    var path: String {
        switch self {
        case .login:                "/api/v1/auth/login"
        case .signup:               "/api/v1/auth/signup"
        case .register:             "/api/v1/auth/register"
        case .refresh:              "/api/v1/auth/refresh"
        case .logout:               "/api/v1/auth/logout"
        case .users:                "/api/v1/users"
        case .updateUser(let id):   "/api/v1/users/\(id)"
        case .deleteUser(let id):   "/api/v1/users/\(id)"
        case .teams:                "/api/v1/teams"
        case .team(let id):         "/api/v1/teams/\(id)"
        case .createTeam:           "/api/v1/teams"
        case .updateTeam(let id):   "/api/v1/teams/\(id)"
        case .deleteTeam(let id):   "/api/v1/teams/\(id)"
        case .teamPlayers(let id):  "/api/v1/teams/\(id)/players"
        case .createPlayer:         "/api/v1/players"
        case .updatePlayer(let id): "/api/v1/players/\(id)"
        case .deletePlayer(let id): "/api/v1/players/\(id)"
        case .games:                "/api/v1/games"
        case .game(let id):         "/api/v1/games/\(id)"
        case .createGame:           "/api/v1/games"
        case .updateGameStatus(let id): "/api/v1/games/\(id)/status"
        case .gameEvents(let id):       "/api/v1/games/\(id)/events"
        case .createGameEvent(let id):  "/api/v1/games/\(id)/events"
        case .deleteGameEvent(let gameID, let eventID): "/api/v1/games/\(gameID)/events/\(eventID)"
        }
    }

    var method: String {
        switch self {
        case .login, .signup, .register, .refresh, .logout, .createTeam, .createPlayer, .createGame, .createGameEvent:
            "POST"
        case .teams, .team, .teamPlayers, .games, .game, .gameEvents, .users:
            "GET"
        case .updateTeam, .updatePlayer, .updateUser:
            "PUT"
        case .deleteTeam, .deletePlayer, .deleteGameEvent, .deleteUser:
            "DELETE"
        case .updateGameStatus:
            "PATCH"
        }
    }

    var requiresAuth: Bool {
        switch self {
        case .login, .signup, .refresh:
            false
        default:
            true
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .games(let page, let perPage, let status, let teamId, let dateFrom, let dateTo):
            var items = [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "perPage", value: "\(perPage)"),
            ]
            if let status { items.append(URLQueryItem(name: "status", value: status)) }
            if let teamId { items.append(URLQueryItem(name: "teamId", value: teamId.uuidString)) }
            if let dateFrom { items.append(URLQueryItem(name: "dateFrom", value: dateFrom)) }
            if let dateTo { items.append(URLQueryItem(name: "dateTo", value: dateTo)) }
            return items
        default:
            return nil
        }
    }
}
