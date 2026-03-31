@testable import App
import VaporTesting
import Testing
import Fluent
import BaseballShared

@Suite(.serialized)
struct TeamTests {

    // MARK: - List

    @Test func listTeamsEmpty() async throws {
        try await withApp(configure: configure) { app in
            try await cleanupTeams(on: app.db)
            let token = try await loginAdmin(app: app)

            try await app.testing().test(.GET, "api/v1/teams", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
            }, afterResponse: { res async in
                #expect(res.status == .ok)
                let teams = try? res.content.decode([TeamResponse].self)
                #expect(teams?.isEmpty == true)
            })
        }
    }

    @Test func listTeamsReturnsCreatedTeams() async throws {
        try await withApp(configure: configure) { app in
            try await cleanupTeams(on: app.db)
            let token = try await loginAdmin(app: app)
            try await createTeam(app: app, token: token, name: "Roosters", shortName: "RST")
            try await createTeam(app: app, token: token, name: "Eagles", shortName: "EGL")

            try await app.testing().test(.GET, "api/v1/teams", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
            }, afterResponse: { res async in
                #expect(res.status == .ok)
                let teams = try? res.content.decode([TeamResponse].self)
                #expect(teams?.count == 2)
                #expect(teams?.first?.name == "Eagles")
                #expect(teams?.last?.name == "Roosters")
            })

            try await cleanupTeams(on: app.db)
        }
    }

    @Test func listTeamsSearchFilter() async throws {
        try await withApp(configure: configure) { app in
            try await cleanupTeams(on: app.db)
            let token = try await loginAdmin(app: app)
            try await createTeam(app: app, token: token, name: "Roosters", shortName: "RST")
            try await createTeam(app: app, token: token, name: "Eagles", shortName: "EGL")

            try await app.testing().test(.GET, "api/v1/teams?search=roost", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
            }, afterResponse: { res async in
                #expect(res.status == .ok)
                let teams = try? res.content.decode([TeamResponse].self)
                #expect(teams?.count == 1)
                #expect(teams?.first?.name == "Roosters")
            })

            try await cleanupTeams(on: app.db)
        }
    }

    // MARK: - Show

    @Test func showTeam() async throws {
        try await withApp(configure: configure) { app in
            try await cleanupTeams(on: app.db)
            let token = try await loginAdmin(app: app)
            let team = try await createTeam(app: app, token: token, name: "Show Roosters", shortName: "SHR")

            try await app.testing().test(.GET, "api/v1/teams/\(team.id)", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
            }, afterResponse: { res async in
                #expect(res.status == .ok)
                let detail = try? res.content.decode(TeamDetailResponse.self)
                #expect(detail?.name == "Show Roosters")
                #expect(detail?.shortName == "SHR")
                #expect(detail?.players.isEmpty == true)
            })

            try await cleanupTeams(on: app.db)
        }
    }

    @Test func showTeamNotFound() async throws {
        try await withApp(configure: configure) { app in
            let token = try await loginAdmin(app: app)

            try await app.testing().test(.GET, "api/v1/teams/\(UUID())", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
            }, afterResponse: { res async in
                #expect(res.status == .notFound)
            })
        }
    }

    // MARK: - Create

    @Test func createTeamSuccess() async throws {
        try await withApp(configure: configure) { app in
            try await cleanupTeams(on: app.db)
            let token = try await loginAdmin(app: app)

            try await app.testing().test(.POST, "api/v1/teams", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
                try req.content.encode(TeamRequest(name: "New Roosters", shortName: "NRS"))
            }, afterResponse: { res async in
                #expect(res.status == .created)
                let team = try? res.content.decode(TeamResponse.self)
                #expect(team?.name == "New Roosters")
                #expect(team?.shortName == "NRS")
            })

            try await cleanupTeams(on: app.db)
        }
    }

    @Test func createTeamDuplicateName() async throws {
        try await withApp(configure: configure) { app in
            try await cleanupTeams(on: app.db)
            let token = try await loginAdmin(app: app)
            try await createTeam(app: app, token: token, name: "Dup Roosters", shortName: "DPR")

            try await app.testing().test(.POST, "api/v1/teams", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
                try req.content.encode(TeamRequest(name: "Dup Roosters", shortName: "DUP"))
            }, afterResponse: { res async in
                #expect(res.status == .conflict)
            })

            try await cleanupTeams(on: app.db)
        }
    }

    @Test func createTeamWithoutAuth() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.POST, "api/v1/teams", beforeRequest: { req in
                try req.content.encode(TeamRequest(name: "No Auth Team", shortName: "NAT"))
            }, afterResponse: { res async in
                #expect(res.status == .unauthorized)
            })
        }
    }

    @Test func createTeamAsNonAdmin() async throws {
        try await withApp(configure: configure) { app in
            try await cleanupUser(email: "scorer-team-test@test.com", on: app.db)
            let adminToken = try await loginAdmin(app: app)

            try await app.testing().test(.POST, "api/v1/auth/register", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: adminToken)
                try req.content.encode(RegisterRequest(
                    email: "scorer-team-test@test.com",
                    password: "password123",
                    name: "Scorer",
                    role: .scorer
                ))
            }, afterResponse: { res async in
                #expect(res.status == .created)
            })

            let scorerLogin = try await loginFull(app: app, email: "scorer-team-test@test.com", password: "password123")

            try await app.testing().test(.POST, "api/v1/teams", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: scorerLogin.accessToken)
                try req.content.encode(TeamRequest(name: "Scorer Team", shortName: "SCT"))
            }, afterResponse: { res async in
                #expect(res.status == .forbidden)
            })

            try await cleanupUser(email: "scorer-team-test@test.com", on: app.db)
        }
    }

    // MARK: - Update

    @Test func updateTeam() async throws {
        try await withApp(configure: configure) { app in
            try await cleanupTeams(on: app.db)
            let token = try await loginAdmin(app: app)
            let team = try await createTeam(app: app, token: token, name: "Update Me", shortName: "UPD")

            try await app.testing().test(.PUT, "api/v1/teams/\(team.id)", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
                try req.content.encode(TeamRequest(name: "Updated Name", shortName: "UPN"))
            }, afterResponse: { res async in
                #expect(res.status == .ok)
                let updated = try? res.content.decode(TeamResponse.self)
                #expect(updated?.name == "Updated Name")
                #expect(updated?.shortName == "UPN")
            })

            try await cleanupTeams(on: app.db)
        }
    }

    @Test func updateTeamDuplicateName() async throws {
        try await withApp(configure: configure) { app in
            try await cleanupTeams(on: app.db)
            let token = try await loginAdmin(app: app)
            try await createTeam(app: app, token: token, name: "First Team", shortName: "FT1")
            let second = try await createTeam(app: app, token: token, name: "Second Team", shortName: "ST2")

            try await app.testing().test(.PUT, "api/v1/teams/\(second.id)", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
                try req.content.encode(TeamRequest(name: "First Team", shortName: "ST2"))
            }, afterResponse: { res async in
                #expect(res.status == .conflict)
            })

            try await cleanupTeams(on: app.db)
        }
    }

    // MARK: - Delete (Soft)

    @Test func softDeleteTeam() async throws {
        try await withApp(configure: configure) { app in
            try await cleanupTeams(on: app.db)
            let token = try await loginAdmin(app: app)
            let team = try await createTeam(app: app, token: token, name: "Delete Me", shortName: "DEL")

            try await app.testing().test(.DELETE, "api/v1/teams/\(team.id)", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
            }, afterResponse: { res async in
                #expect(res.status == .noContent)
            })

            // Should not appear in list
            try await app.testing().test(.GET, "api/v1/teams", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
            }, afterResponse: { res async in
                let teams = try? res.content.decode([TeamResponse].self)
                let found = teams?.contains { $0.name == "Delete Me" }
                #expect(found != true)
            })

            // Should still exist in DB (soft deleted)
            let softDeleted = try await Team.query(on: app.db)
                .withDeleted()
                .filter(\.$name, .equal, "Delete Me")
                .first()
            #expect(softDeleted != nil)
            #expect(softDeleted?.deletedAt != nil)

            try await cleanupTeams(on: app.db)
        }
    }

    @Test func deleteTeamNotFound() async throws {
        try await withApp(configure: configure) { app in
            let token = try await loginAdmin(app: app)

            try await app.testing().test(.DELETE, "api/v1/teams/\(UUID())", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
            }, afterResponse: { res async in
                #expect(res.status == .notFound)
            })
        }
    }

    // MARK: - Helpers

    private func loginAdmin(app: Application) async throws -> String {
        let response = try await loginFull(app: app, email: "admin@baseball.local", password: "aDminComplexPa55")
        try await RefreshToken.query(on: app.db)
            .filter(\.$token, .equal, response.refreshToken)
            .delete()
        return response.accessToken
    }

    private func loginFull(app: Application, email: String, password: String) async throws -> TokenResponse {
        let res = try await app.testing().sendRequest(.POST, "api/v1/auth/login", beforeRequest: { req in
            try req.content.encode(LoginRequest(email: email, password: password))
        })
        return try res.content.decode(TokenResponse.self)
    }

    @discardableResult
    private func createTeam(app: Application, token: String, name: String, shortName: String?) async throws -> TeamResponse {
        let res = try await app.testing().sendRequest(.POST, "api/v1/teams", beforeRequest: { req in
            req.headers.bearerAuthorization = .init(token: token)
            try req.content.encode(TeamRequest(name: name, shortName: shortName))
        })
        return try res.content.decode(TeamResponse.self)
    }

    private func cleanupTeams(on db: any Database) async throws {
        try await Team.query(on: db).withDeleted().delete(force: true)
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
