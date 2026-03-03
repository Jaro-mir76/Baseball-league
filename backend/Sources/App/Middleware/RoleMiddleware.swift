import Vapor
import BaseballShared

struct RoleMiddleware: AsyncMiddleware {
    let requiredRoles: [UserRole]

    init(_ roles: UserRole...) {
        self.requiredRoles = roles
    }

    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        guard let user = request.auth.get(AuthenticatedUser.self) else {
            throw Abort(.unauthorized)
        }

        guard requiredRoles.contains(user.role) else {
            throw Abort(.forbidden, reason: "Insufficient permissions")
        }

        return try await next.respond(to: request)
    }
}
