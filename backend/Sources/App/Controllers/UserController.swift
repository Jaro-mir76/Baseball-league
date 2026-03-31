import Vapor
import Fluent
import BaseballShared

struct UserController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let users = routes.grouped("users")
        let adminOnly = users.grouped(JWTAuthMiddleware()).grouped(RoleMiddleware(.admin))

        adminOnly.get(use: index)
        adminOnly.put(":userID", use: update)
        adminOnly.delete(":userID", use: delete)
    }

    // MARK: - GET /users

    @Sendable
    func index(req: Request) async throws -> [UserResponse] {
        let users = try await User.query(on: req.db)
            .sort(\.$name)
            .all()
        return users.map { $0.toResponse() }
    }

    // MARK: - PUT /users/:userID

    @Sendable
    func update(req: Request) async throws -> UserResponse {
        guard let userID: UUID = req.parameters.get("userID") else {
            throw Abort(.badRequest)
        }

        let caller = try req.auth.require(AuthenticatedUser.self)

        guard let user = try await User.find(userID, on: req.db) else {
            throw Abort(.notFound)
        }

        try UserUpdateRequest.validate(content: req)
        let input = try req.content.decode(UserUpdateRequest.self)

        if caller.id == userID && input.role != user.role {
            throw Abort(.forbidden, reason: "Cannot change your own role")
        }

        user.name = input.name
        user.role = input.role
        try await user.save(on: req.db)

        return user.toResponse()
    }

    // MARK: - DELETE /users/:userID

    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        guard let userID: UUID = req.parameters.get("userID") else {
            throw Abort(.badRequest)
        }

        let caller = try req.auth.require(AuthenticatedUser.self)

        if caller.id == userID {
            throw Abort(.forbidden, reason: "Cannot delete your own account")
        }

        guard let user = try await User.find(userID, on: req.db) else {
            throw Abort(.notFound)
        }

        try await user.delete(on: req.db)
        return .noContent
    }
}
