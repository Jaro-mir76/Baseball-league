import Vapor
import JWT
import BaseballShared

struct JWTAuthMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        let payload = try request.jwt.verify(as: JWTUserPayload.self)

        guard let userID = payload.userID else {
            throw Abort(.unauthorized, reason: "Invalid token subject")
        }

        request.auth.login(AuthenticatedUser(
            id: userID,
            role: payload.role,
            name: payload.name
        ))

        return try await next.respond(to: request)
    }
}

struct AuthenticatedUser: Authenticatable {
    let id: UUID
    let role: UserRole
    let name: String
}
