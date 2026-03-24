import Foundation

nonisolated enum Endpoint: Sendable {
    // MARK: - Auth
    case login
    case register
    case refresh
    case logout

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

    var path: String {
        switch self {
        case .login:                "/api/v1/auth/login"
        case .register:             "/api/v1/auth/register"
        case .refresh:              "/api/v1/auth/refresh"
        case .logout:               "/api/v1/auth/logout"
        case .teams:                "/api/v1/teams"
        case .team(let id):         "/api/v1/teams/\(id)"
        case .createTeam:           "/api/v1/teams"
        case .updateTeam(let id):   "/api/v1/teams/\(id)"
        case .deleteTeam(let id):   "/api/v1/teams/\(id)"
        case .teamPlayers(let id):  "/api/v1/teams/\(id)/players"
        case .createPlayer:         "/api/v1/players"
        case .updatePlayer(let id): "/api/v1/players/\(id)"
        case .deletePlayer(let id): "/api/v1/players/\(id)"
        }
    }

    var method: String {
        switch self {
        case .login, .register, .refresh, .logout, .createTeam, .createPlayer:
            "POST"
        case .teams, .team, .teamPlayers:
            "GET"
        case .updateTeam, .updatePlayer:
            "PUT"
        case .deleteTeam, .deletePlayer:
            "DELETE"
        }
    }

    var requiresAuth: Bool {
        switch self {
        case .login, .register, .refresh:
            false
        case .teams, .team, .teamPlayers:
            false
        case .logout, .createTeam, .updateTeam, .deleteTeam,
             .createPlayer, .updatePlayer, .deletePlayer:
            true
        }
    }
}
