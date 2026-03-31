@testable import App
import VaporTesting
import Fluent
import Testing
import BaseballShared

@Suite(.serialized)
struct UserTests {

    // MARK: - List

    @Test func listUsersAsAdmin() async throws {
        try await withApp(configure: configure) { app in
            let token = try await loginAdmin(app: app)

            // Create a test user
            try await createUser(app: app, token: token, email: "listuser@test.com", name: "List User", role: .viewer)

            try await app.testing().test(.GET, "api/v1/users", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
            }, afterResponse: { res async in
                #expect(res.status == .ok)
                let users = try? res.content.decode([UserResponse].self)
                #expect(users != nil)
                // At least the admin + the test user
                #expect((users?.count ?? 0) >= 2)
                #expect(users?.contains(where: { $0.email == "listuser@test.com" }) == true)
            })

            try await cleanupUser(email: "listuser@test.com", on: app.db)
        }
    }

    @Test func listUsersAsNonAdmin() async throws {
        try await withApp(configure: configure) { app in
            let adminToken = try await loginAdmin(app: app)
            try await createUser(app: app, token: adminToken, email: "scorer-list@test.com", name: "Scorer", role: .scorer)

            let scorerLogin = try await loginFull(app: app, email: "scorer-list@test.com", password: "password123")

            try await app.testing().test(.GET, "api/v1/users", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: scorerLogin.accessToken)
            }, afterResponse: { res async in
                #expect(res.status == .forbidden)
            })

            try await cleanupUser(email: "scorer-list@test.com", on: app.db)
        }
    }

    @Test func listUsersWithoutAuth() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "api/v1/users", afterResponse: { res async in
                #expect(res.status == .unauthorized)
            })
        }
    }

    // MARK: - Update

    @Test func updateUserRole() async throws {
        try await withApp(configure: configure) { app in
            let token = try await loginAdmin(app: app)
            let userId = try await createUser(app: app, token: token, email: "update-role@test.com", name: "Role Test", role: .viewer)

            try await app.testing().test(.PUT, "api/v1/users/\(userId)", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
                try req.content.encode(UserUpdateRequest(name: "Role Test", role: .scorer))
            }, afterResponse: { res async in
                #expect(res.status == .ok)
                let user = try? res.content.decode(UserResponse.self)
                #expect(user?.role == .scorer)
                #expect(user?.name == "Role Test")
            })

            try await cleanupUser(email: "update-role@test.com", on: app.db)
        }
    }

    @Test func updateUserName() async throws {
        try await withApp(configure: configure) { app in
            let token = try await loginAdmin(app: app)
            let userId = try await createUser(app: app, token: token, email: "update-name@test.com", name: "Old Name", role: .viewer)

            try await app.testing().test(.PUT, "api/v1/users/\(userId)", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
                try req.content.encode(UserUpdateRequest(name: "New Name", role: .viewer))
            }, afterResponse: { res async in
                #expect(res.status == .ok)
                let user = try? res.content.decode(UserResponse.self)
                #expect(user?.name == "New Name")
            })

            try await cleanupUser(email: "update-name@test.com", on: app.db)
        }
    }

    @Test func updateUserNotFound() async throws {
        try await withApp(configure: configure) { app in
            let token = try await loginAdmin(app: app)
            let fakeId = UUID()

            try await app.testing().test(.PUT, "api/v1/users/\(fakeId)", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
                try req.content.encode(UserUpdateRequest(name: "Ghost", role: .viewer))
            }, afterResponse: { res async in
                #expect(res.status == .notFound)
            })
        }
    }

    @Test func cannotChangeOwnRole() async throws {
        try await withApp(configure: configure) { app in
            let loginResponse = try await loginAdminFull(app: app)
            let adminId = loginResponse.user!.id

            try await app.testing().test(.PUT, "api/v1/users/\(adminId)", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: loginResponse.accessToken)
                try req.content.encode(UserUpdateRequest(name: "Admin", role: .viewer))
            }, afterResponse: { res async in
                #expect(res.status == .forbidden)
            })

            // Cleanup refresh token
            try await RefreshToken.query(on: app.db)
                .filter(\.$token, .equal, loginResponse.refreshToken)
                .delete()
        }
    }

    // MARK: - Delete

    @Test func deleteUser() async throws {
        try await withApp(configure: configure) { app in
            let token = try await loginAdmin(app: app)
            let userId = try await createUser(app: app, token: token, email: "delete-me@test.com", name: "Delete Me", role: .viewer)

            try await app.testing().test(.DELETE, "api/v1/users/\(userId)", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
            }, afterResponse: { res async in
                #expect(res.status == .noContent)
            })

            // Verify not in list
            try await app.testing().test(.GET, "api/v1/users", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
            }, afterResponse: { res async in
                let users = try? res.content.decode([UserResponse].self)
                #expect(users?.contains(where: { $0.id == userId }) == false)
            })

            // Force cleanup
            try await cleanupUser(email: "delete-me@test.com", on: app.db)
        }
    }

    @Test func cannotDeleteSelf() async throws {
        try await withApp(configure: configure) { app in
            let loginResponse = try await loginAdminFull(app: app)
            let adminId = loginResponse.user!.id

            try await app.testing().test(.DELETE, "api/v1/users/\(adminId)", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: loginResponse.accessToken)
            }, afterResponse: { res async in
                #expect(res.status == .forbidden)
            })

            // Cleanup refresh token
            try await RefreshToken.query(on: app.db)
                .filter(\.$token, .equal, loginResponse.refreshToken)
                .delete()
        }
    }

    @Test func deleteUserNotFound() async throws {
        try await withApp(configure: configure) { app in
            let token = try await loginAdmin(app: app)
            let fakeId = UUID()

            try await app.testing().test(.DELETE, "api/v1/users/\(fakeId)", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
            }, afterResponse: { res async in
                #expect(res.status == .notFound)
            })
        }
    }

    // MARK: - Helpers

    @discardableResult
    private func createUser(app: Application, token: String, email: String, name: String, role: UserRole) async throws -> UUID {
        let res = try await app.testing().sendRequest(.POST, "api/v1/auth/register", beforeRequest: { req in
            req.headers.bearerAuthorization = .init(token: token)
            try req.content.encode(RegisterRequest(
                email: email,
                password: "password123",
                name: name,
                role: role
            ))
        })
        let user = try res.content.decode(UserResponse.self)
        return user.id
    }

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

    private func cleanupUser(email: String, on db: any Database) async throws {
        if let user = try await User.query(on: db)
            .withDeleted()
            .filter(\.$email, .equal, email)
            .first() {
            try await RefreshToken.query(on: db)
                .filter(\.$user.$id, .equal, try user.requireID())
                .delete()
            try await user.delete(force: true, on: db)
        }
    }
}
