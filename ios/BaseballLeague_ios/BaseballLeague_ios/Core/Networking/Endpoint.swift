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

    var path: String {
        switch self {
        case .login:              "/api/v1/auth/login"
        case .register:           "/api/v1/auth/register"
        case .refresh:            "/api/v1/auth/refresh"
        case .logout:             "/api/v1/auth/logout"
        case .teams:              "/api/v1/teams"
        case .team(let id):       "/api/v1/teams/\(id)"
        case .createTeam:         "/api/v1/teams"
        case .updateTeam(let id): "/api/v1/teams/\(id)"
        case .deleteTeam(let id): "/api/v1/teams/\(id)"
        }
    }

    var method: String {
        switch self {
        case .login, .register, .refresh, .logout, .createTeam:
            "POST"
        case .teams, .team:
            "GET"
        case .updateTeam:
            "PUT"
        case .deleteTeam:
            "DELETE"
        }
    }

    var requiresAuth: Bool {
        switch self {
        case .login, .register, .refresh:
            false
        case .teams, .team:
            false
        case .logout, .createTeam, .updateTeam, .deleteTeam:
            true
        }
    }
}
