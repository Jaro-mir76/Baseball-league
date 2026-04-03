import Vapor
import BaseballShared

struct AuthController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let auth = routes.grouped("auth")

        let rateLimited = auth.grouped(RateLimitMiddleware(maxRequests: 5, windowSeconds: 60))
        rateLimited.post("login", use: login)
        rateLimited.post("signup", use: signup)
        auth.post("refresh", use: refresh)

        let protected = auth.grouped(JWTAuthMiddleware())
        protected.post("logout", use: logout)

        let adminOnly = auth.grouped(JWTAuthMiddleware()).grouped(RoleMiddleware(.admin))
        adminOnly.post("register", use: register)
    }

    @Sendable
    func register(req: Request) async throws -> Response {
        try RegisterRequest.validate(content: req)
        let input = try req.content.decode(RegisterRequest.self)
        let service = AuthService(app: req.application)
        let user = try await service.register(input, on: req.db)
        return try await user.encodeResponse(status: .created, for: req)
    }

    @Sendable
    func signup(req: Request) async throws -> Response {
        try RegisterRequest.validate(content: req)
        let input = try req.content.decode(RegisterRequest.self)
        let service = AuthService(app: req.application)
        let response = try await service.signup(input, on: req.db)
        return try await response.encodeResponse(status: .created, for: req)
    }

    @Sendable
    func login(req: Request) async throws -> TokenResponse {
        let input = try req.content.decode(LoginRequest.self)
        let service = AuthService(app: req.application)
        return try await service.login(input, on: req.db)
    }

    @Sendable
    func refresh(req: Request) async throws -> TokenResponse {
        let input = try req.content.decode(RefreshRequest.self)
        let service = AuthService(app: req.application)
        return try await service.refresh(input, on: req.db)
    }

    @Sendable
    func logout(req: Request) async throws -> HTTPStatus {
        let input = try req.content.decode(RefreshRequest.self)
        let service = AuthService(app: req.application)
        try await service.logout(input.refreshToken, on: req.db)
        return .noContent
    }
}
