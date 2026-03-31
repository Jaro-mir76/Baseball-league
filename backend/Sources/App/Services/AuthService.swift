import Vapor
import Fluent
import JWT
import BaseballShared

struct AuthService {
    let app: Application

    // MARK: - Registration

    func register(_ request: RegisterRequest, on db: any Database) async throws -> UserResponse {
        let email = request.email.lowercased().trimmingCharacters(in: .whitespaces)

        let existing = try await User.query(on: db)
            .filter(\.$email == email)
            .withDeleted()
            .first()
        if existing != nil {
            throw Abort(.conflict, reason: "Email already registered")
        }

        let passwordHash = try Bcrypt.hash(request.password)

        let user = User(
            email: email,
            passwordHash: passwordHash,
            name: request.name,
            role: request.role
        )
        try await user.save(on: db)

        return user.toResponse()
    }

    // MARK: - Public Signup

    func signup(_ request: RegisterRequest, on db: any Database) async throws -> TokenResponse {
        let email = request.email.lowercased().trimmingCharacters(in: .whitespaces)

        let existing = try await User.query(on: db)
            .filter(\.$email == email)
            .withDeleted()
            .first()
        if existing != nil {
            throw Abort(.conflict, reason: "Email already registered")
        }

        let passwordHash = try Bcrypt.hash(request.password)

        let user = User(
            email: email,
            passwordHash: passwordHash,
            name: request.name,
            role: .viewer
        )
        try await user.save(on: db)

        let tokenPair = try generateTokens(for: user)
        let refreshToken = RefreshToken(
            token: tokenPair.refreshToken,
            userID: try user.requireID(),
            expiresAt: Date().addingTimeInterval(30 * 24 * 60 * 60)
        )
        try await refreshToken.save(on: db)

        return TokenResponse(
            accessToken: tokenPair.accessToken,
            refreshToken: tokenPair.refreshToken,
            user: user.toResponse()
        )
    }

    // MARK: - Login

    func login(_ request: LoginRequest, on db: any Database) async throws -> TokenResponse {
        let email = request.email.lowercased().trimmingCharacters(in: .whitespaces)

        guard let user = try await User.query(on: db)
            .filter(\.$email == email)
            .first()
        else {
            throw Abort(.unauthorized, reason: "Invalid email or password")
        }

        guard try Bcrypt.verify(request.password, created: user.passwordHash) else {
            throw Abort(.unauthorized, reason: "Invalid email or password")
        }

        let tokenPair = try generateTokens(for: user)
        let refreshToken = RefreshToken(
            token: tokenPair.refreshToken,
            userID: try user.requireID(),
            expiresAt: Date().addingTimeInterval(30 * 24 * 60 * 60) // 30 days
        )
        try await refreshToken.save(on: db)

        return TokenResponse(
            accessToken: tokenPair.accessToken,
            refreshToken: tokenPair.refreshToken,
            user: user.toResponse()
        )
    }

    // MARK: - Token Refresh

    func refresh(_ request: RefreshRequest, on db: any Database) async throws -> TokenResponse {
        guard let storedToken = try await RefreshToken.query(on: db)
            .filter(\.$token == request.refreshToken)
            .with(\.$user)
            .first()
        else {
            throw Abort(.unauthorized, reason: "Invalid refresh token")
        }

        guard storedToken.expiresAt > Date() else {
            try await storedToken.delete(on: db)
            throw Abort(.unauthorized, reason: "Refresh token expired")
        }

        let user = storedToken.user

        // Revoke old token
        try await storedToken.delete(on: db)

        // Issue new pair
        let tokenPair = try generateTokens(for: user)
        let newRefreshToken = RefreshToken(
            token: tokenPair.refreshToken,
            userID: try user.requireID(),
            expiresAt: Date().addingTimeInterval(30 * 24 * 60 * 60)
        )
        try await newRefreshToken.save(on: db)

        return TokenResponse(
            accessToken: tokenPair.accessToken,
            refreshToken: tokenPair.refreshToken,
            user: nil
        )
    }

    // MARK: - Logout (revoke refresh token)

    func logout(_ refreshTokenString: String, on db: any Database) async throws {
        guard let storedToken = try await RefreshToken.query(on: db)
            .filter(\.$token == refreshTokenString)
            .first()
        else {
            return // Token not found — already revoked or invalid, no-op
        }
        try await storedToken.delete(on: db)
    }

    // MARK: - Token Generation

    private func generateTokens(for user: User) throws -> (accessToken: String, refreshToken: String) {
        let payload = JWTUserPayload(
            userID: try user.requireID(),
            role: user.role,
            name: user.name,
            expiresAt: Date().addingTimeInterval(15 * 60) // 15 minutes
        )

        let accessToken = try app.jwt.signers.sign(payload)
        let refreshToken = [UInt8].random(count: 32).base64
        return (accessToken, refreshToken)
    }
}
