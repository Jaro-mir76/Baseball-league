@testable import App
import VaporTesting
import Testing
import BaseballShared

struct AuthTests {

    // MARK: - Login

    @Test func loginWithValidCredentials() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.POST, "api/v1/auth/login", beforeRequest: { req in
                try req.content.encode(LoginRequest(
                    email: "admin@baseball.local",
                    password: "aDminComplexPa55"
                ))
            }, afterResponse: { res async in
                #expect(res.status == .ok)
                let token = try? res.content.decode(TokenResponse.self)
                #expect(token != nil)
                #expect(token?.accessToken.isEmpty == false)
                #expect(token?.refreshToken.isEmpty == false)
                #expect(token?.user?.role == .admin)
                #expect(token?.user?.email == "admin@baseball.local")
            })
        }
    }

    @Test func loginWithWrongPassword() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.POST, "api/v1/auth/login", beforeRequest: { req in
                try req.content.encode(LoginRequest(
                    email: "admin@baseball.local",
                    password: "wrongpassword"
                ))
            }, afterResponse: { res async in
                #expect(res.status == .unauthorized)
            })
        }
    }

    @Test func loginWithNonexistentEmail() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.POST, "api/v1/auth/login", beforeRequest: { req in
                try req.content.encode(LoginRequest(
                    email: "nobody@example.com",
                    password: "password123"
                ))
            }, afterResponse: { res async in
                #expect(res.status == .unauthorized)
            })
        }
    }

    // MARK: - Register

    @Test func registerAsAdmin() async throws {
        try await withApp(configure: configure) { app in
            
            let adminToken = try await loginAdmin(app: app)

            try await app.testing().test(.POST, "api/v1/auth/register", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: adminToken)
                try req.content.encode(RegisterRequest(
                    email: "scorer-reg@test.com",
                    password: "password123",
                    name: "Test Scorer",
                    role: .scorer
                ))
            }, afterResponse: { res async in
                #expect(res.status == .created)
                let user = try? res.content.decode(UserResponse.self)
                #expect(user?.email == "scorer-reg@test.com")
                #expect(user?.role == .scorer)
                #expect(user?.name == "Test Scorer")
            })

            // Cleanup
            try await User.query(on: app.db).filter(\.$email, .equal, "scorer-reg@test.com").delete(force: true)
        }
    }

    @Test func registerWithoutAuth() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.POST, "api/v1/auth/register", beforeRequest: { req in
                try req.content.encode(RegisterRequest(
                    email: "scorer@test.com",
                    password: "password123",
                    name: "Test Scorer",
                    role: .scorer
                ))
            }, afterResponse: { res async in
                #expect(res.status == .unauthorized)
            })
        }
    }

    @Test func registerDuplicateEmail() async throws {
        try await withApp(configure: configure) { app in
            let adminToken = try await loginAdmin(app: app)

            try await app.testing().test(.POST, "api/v1/auth/register", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: adminToken)
                try req.content.encode(RegisterRequest(
                    email: "admin@baseball.local",
                    password: "password123",
                    name: "Duplicate",
                    role: .viewer
                ))
            }, afterResponse: { res async in
                #expect(res.status == .conflict)
            })
        }
    }

    @Test func registerWithShortPassword() async throws {
        try await withApp(configure: configure) { app in
            let adminToken = try await loginAdmin(app: app)

            try await app.testing().test(.POST, "api/v1/auth/register", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: adminToken)
                try req.content.encode(RegisterRequest(
                    email: "short@test.com",
                    password: "abc",
                    name: "Short Pass",
                    role: .viewer
                ))
            }, afterResponse: { res async in
                #expect(res.status == .badRequest)
            })
        }
    }

    // MARK: - Refresh

    @Test func refreshToken() async throws {
        try await withApp(configure: configure) { app in
            let loginResponse = try await loginAdminFull(app: app)

            try await app.testing().test(.POST, "api/v1/auth/refresh", beforeRequest: { req in
                try req.content.encode(RefreshRequest(refreshToken: loginResponse.refreshToken))
            }, afterResponse: { res async in
                #expect(res.status == .ok)
                let token = try? res.content.decode(TokenResponse.self)
                #expect(token != nil)
                #expect(token?.accessToken.isEmpty == false)
                #expect(token?.refreshToken != loginResponse.refreshToken)
            })

            // Cleanup
            try await RefreshToken.query(on: app.db).delete()
        }
    }

    @Test func refreshWithInvalidToken() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.POST, "api/v1/auth/refresh", beforeRequest: { req in
                try req.content.encode(RefreshRequest(refreshToken: "invalid-token"))
            }, afterResponse: { res async in
                #expect(res.status == .unauthorized)
            })
        }
    }

    // MARK: - Logout

    @Test func logout() async throws {
        try await withApp(configure: configure) { app in
            let loginResponse = try await loginAdminFull(app: app)

            try await app.testing().test(.POST, "api/v1/auth/logout", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: loginResponse.accessToken)
                try req.content.encode(RefreshRequest(refreshToken: loginResponse.refreshToken))
            }, afterResponse: { res async in
                #expect(res.status == .noContent)
            })

            // Verify refresh token is revoked
            try await app.testing().test(.POST, "api/v1/auth/refresh", beforeRequest: { req in
                try req.content.encode(RefreshRequest(refreshToken: loginResponse.refreshToken))
            }, afterResponse: { res async in
                #expect(res.status == .unauthorized)
            })
        }
    }

    // MARK: - Role Check

    @Test func scorerCannotRegisterUsers() async throws {
        try await withApp(configure: configure) { app in
            
// MARK: to ensure we have clean env before test
            try await cleanup()
            
            let adminToken = try await loginAdmin(app: app)

            // Create a scorer
            try await app.testing().test(.POST, "api/v1/auth/register", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: adminToken)
                try req.content.encode(RegisterRequest(
                    email: "scorer-role-test@test.com",
                    password: "password123",
                    name: "Scorer Role Test",
                    role: .scorer
                ))
            }, afterResponse: { res async in
                #expect(res.status == .created)
            })

            // Login as scorer
            let scorerLogin = try await loginFull(app: app, email: "scorer-role-test@test.com", password: "password123")

            // Try to register as scorer — should be forbidden
            try await app.testing().test(.POST, "api/v1/auth/register", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: scorerLogin.accessToken)
                try req.content.encode(RegisterRequest(
                    email: "another@test.com",
                    password: "password123",
                    name: "Another",
                    role: .viewer
                ))
            }, afterResponse: { res async in
                #expect(res.status == .forbidden)
            })

            // Cleanup
            try await cleanup()
            
            func cleanup() async throws {
                if let user = try await User.query(on: app.db)
                    .withDeleted()
                    .filter(\.$email, .equal, "scorer-role-test@test.com")
                    .first() {
                    try await RefreshToken.query(on: app.db)
                        .filter(\.$user.$id, .equal, try user.requireID())
                        .delete()
                    try await user.delete(force: true, on: app.db)
                }
            }
        }
    }

    // MARK: - Helpers

    private func loginAdmin(app: Application) async throws -> String {
        let response = try await loginAdminFull(app: app)
        try await RefreshToken.query(on: app.db)
            .filter(\.$token, .equal, response.refreshToken)
            .delete()
        return response.accessToken
    }

    private func loginAdminFull(app: Application) async throws -> TokenResponse {
        try await loginFull(app: app, email: "admin@baseball.local", password: "aDminComplexPa55")
    }

    private func loginFull(app: Application, email: String, password: String) async throws -> TokenResponse {
        let res = try await app.testing().sendRequest(.POST, "api/v1/auth/login", beforeRequest: { req in
            try req.content.encode(LoginRequest(email: email, password: password))
        })
        return try res.content.decode(TokenResponse.self)
    }
}
