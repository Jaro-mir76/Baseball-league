import Foundation

nonisolated enum Endpoint: Sendable {
    // MARK: - Auth
    case login
    case register
    case refresh
    case logout

    var path: String {
        switch self {
        case .login:    "/api/v1/auth/login"
        case .register: "/api/v1/auth/register"
        case .refresh:  "/api/v1/auth/refresh"
        case .logout:   "/api/v1/auth/logout"
        }
    }

    var method: String {
        switch self {
        case .login, .register, .refresh, .logout:
            "POST"
        }
    }

    var requiresAuth: Bool {
        switch self {
        case .login, .register, .refresh:
            false
        case .logout:
            true
        }
    }
}
