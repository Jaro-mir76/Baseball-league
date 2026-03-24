@testable import App
import VaporTesting
import Testing
import Fluent
import BaseballShared

@Suite(.serialized)
struct PlayerTests {

    // MARK: - List by Team

    @Test func listPlayersByTeam() async throws {
        try await withApp(configure: configure) { app in
            try await cleanup(on: app.db)
            let token = try await loginAdmin(app: app)
            let team = try await createTeam(app: app, token: token, name: "PT Roosters", shortName: "PTR")

            try await createPlayer(app: app, token: token, teamId: team.id, firstName: "Mike", lastName: "Johnson", jerseyNumber: 7, position: "SS")
            try await createPlayer(app: app, token: token, teamId: team.id, firstName: "Alex", lastName: "Adams", jerseyNumber: 12, position: "1B")

            try await app.testing().test(.GET, "api/v1/teams/\(team.id)/players", afterResponse: { res async in
                #expect(res.status == .ok)
                let players = try? res.content.decode([PlayerResponse].self)
                #expect(players?.count == 2)
                // Sorted by lastName: Adams before Johnson
                #expect(players?.first?.lastName == "Adams")
                #expect(players?.last?.lastName == "Johnson")
            })

            try await cleanup(on: app.db)
        }
    }

    @Test func listPlayersByTeamNotFound() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "api/v1/teams/\(UUID())/players", afterResponse: { res async in
                #expect(res.status == .notFound)
            })
        }
    }

    @Test func listPlayersEmptyTeam() async throws {
        try await withApp(configure: configure) { app in
            try await cleanup(on: app.db)
            let token = try await loginAdmin(app: app)
            let team = try await createTeam(app: app, token: token, name: "PT Empty", shortName: "PTE")

            try await app.testing().test(.GET, "api/v1/teams/\(team.id)/players", afterResponse: { res async in
                #expect(res.status == .ok)
                let players = try? res.content.decode([PlayerResponse].self)
                #expect(players?.isEmpty == true)
            })

            try await cleanup(on: app.db)
        }
    }

    // MARK: - Create

    @Test func createPlayerSuccess() async throws {
        try await withApp(configure: configure) { app in
            try await cleanup(on: app.db)
            let token = try await loginAdmin(app: app)
            let team = try await createTeam(app: app, token: token, name: "PT Create", shortName: "PTC")

            try await app.testing().test(.POST, "api/v1/players", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
                try req.content.encode(PlayerRequest(firstName: "Mike", lastName: "Johnson", jerseyNumber: 7, position: "SS", teamId: team.id))
            }, afterResponse: { res async in
                #expect(res.status == .created)
                let player = try? res.content.decode(PlayerResponse.self)
                #expect(player?.firstName == "Mike")
                #expect(player?.lastName == "Johnson")
                #expect(player?.jerseyNumber == 7)
                #expect(player?.position == "SS")
                #expect(player?.teamId == team.id)
            })

            try await cleanup(on: app.db)
        }
    }

    @Test func createPlayerWithoutJersey() async throws {
        try await withApp(configure: configure) { app in
            try await cleanup(on: app.db)
            let token = try await loginAdmin(app: app)
            let team = try await createTeam(app: app, token: token, name: "PT NoJersey", shortName: "PNJ")

            try await app.testing().test(.POST, "api/v1/players", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
                try req.content.encode(PlayerRequest(firstName: "Jane", lastName: "Doe", jerseyNumber: nil, position: nil, teamId: team.id))
            }, afterResponse: { res async in
                #expect(res.status == .created)
                let player = try? res.content.decode(PlayerResponse.self)
                #expect(player?.jerseyNumber == nil)
                #expect(player?.position == nil)
            })

            try await cleanup(on: app.db)
        }
    }

    @Test func createPlayerDuplicateJersey() async throws {
        try await withApp(configure: configure) { app in
            try await cleanup(on: app.db)
            let token = try await loginAdmin(app: app)
            let team = try await createTeam(app: app, token: token, name: "PT DupJersey", shortName: "PDJ")

            try await createPlayer(app: app, token: token, teamId: team.id, firstName: "Mike", lastName: "Johnson", jerseyNumber: 7, position: "SS")

            try await app.testing().test(.POST, "api/v1/players", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
                try req.content.encode(PlayerRequest(firstName: "Alex", lastName: "Smith", jerseyNumber: 7, position: "1B", teamId: team.id))
            }, afterResponse: { res async in
                #expect(res.status == .conflict)
            })

            try await cleanup(on: app.db)
        }
    }

    @Test func createPlayerSameJerseyDifferentTeam() async throws {
        try await withApp(configure: configure) { app in
            try await cleanup(on: app.db)
            let token = try await loginAdmin(app: app)
            let team1 = try await createTeam(app: app, token: token, name: "PT Team A", shortName: "PTA")
            let team2 = try await createTeam(app: app, token: token, name: "PT Team B", shortName: "PTB")

            try await createPlayer(app: app, token: token, teamId: team1.id, firstName: "Mike", lastName: "Johnson", jerseyNumber: 7, position: "SS")

            try await app.testing().test(.POST, "api/v1/players", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
                try req.content.encode(PlayerRequest(firstName: "Alex", lastName: "Smith", jerseyNumber: 7, position: "1B", teamId: team2.id))
            }, afterResponse: { res async in
                #expect(res.status == .created)
            })

            try await cleanup(on: app.db)
        }
    }

    @Test func createPlayerTeamNotFound() async throws {
        try await withApp(configure: configure) { app in
            let token = try await loginAdmin(app: app)

            try await app.testing().test(.POST, "api/v1/players", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
                try req.content.encode(PlayerRequest(firstName: "Mike", lastName: "Johnson", jerseyNumber: 7, position: "SS", teamId: UUID()))
            }, afterResponse: { res async in
                #expect(res.status == .notFound)
            })
        }
    }

    @Test func createPlayerWithoutAuth() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.POST, "api/v1/players", beforeRequest: { req in
                try req.content.encode(PlayerRequest(firstName: "Mike", lastName: "Johnson", jerseyNumber: 7, position: "SS", teamId: UUID()))
            }, afterResponse: { res async in
                #expect(res.status == .unauthorized)
            })
        }
    }

    @Test func createPlayerAsNonAdmin() async throws {
        try await withApp(configure: configure) { app in
            try await cleanupUser(email: "scorer-player-test@test.com", on: app.db)
            let adminToken = try await loginAdmin(app: app)

            try await app.testing().test(.POST, "api/v1/auth/register", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: adminToken)
                try req.content.encode(RegisterRequest(email: "scorer-player-test@test.com", password: "password123", name: "Scorer", role: .scorer))
            }, afterResponse: { res async in
                #expect(res.status == .created)
            })

            let scorerLogin = try await loginFull(app: app, email: "scorer-player-test@test.com", password: "password123")

            try await app.testing().test(.POST, "api/v1/players", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: scorerLogin.accessToken)
                try req.content.encode(PlayerRequest(firstName: "Mike", lastName: "Johnson", jerseyNumber: 7, position: "SS", teamId: UUID()))
            }, afterResponse: { res async in
                #expect(res.status == .forbidden)
            })

            try await cleanupUser(email: "scorer-player-test@test.com", on: app.db)
        }
    }

    // MARK: - Validation

    @Test func createPlayerInvalidJerseyNumber() async throws {
        try await withApp(configure: configure) { app in
            try await cleanup(on: app.db)
            let token = try await loginAdmin(app: app)
            let team = try await createTeam(app: app, token: token, name: "PT Validation", shortName: "PTV")

            try await app.testing().test(.POST, "api/v1/players", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
                try req.content.encode(PlayerRequest(firstName: "Mike", lastName: "Johnson", jerseyNumber: 100, position: "SS", teamId: team.id))
            }, afterResponse: { res async in
                #expect(res.status == .badRequest)
            })

            try await cleanup(on: app.db)
        }
    }

    @Test func createPlayerEmptyFirstName() async throws {
        try await withApp(configure: configure) { app in
            try await cleanup(on: app.db)
            let token = try await loginAdmin(app: app)
            let team = try await createTeam(app: app, token: token, name: "PT EmptyName", shortName: "PEN")

            try await app.testing().test(.POST, "api/v1/players", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
                try req.content.encode(PlayerRequest(firstName: "", lastName: "Johnson", jerseyNumber: 7, position: "SS", teamId: team.id))
            }, afterResponse: { res async in
                #expect(res.status == .badRequest)
            })

            try await cleanup(on: app.db)
        }
    }

    // MARK: - Update

    @Test func updatePlayerSuccess() async throws {
        try await withApp(configure: configure) { app in
            try await cleanup(on: app.db)
            let token = try await loginAdmin(app: app)
            let team = try await createTeam(app: app, token: token, name: "PT Update", shortName: "PTU")
            let player = try await createPlayer(app: app, token: token, teamId: team.id, firstName: "Mike", lastName: "Johnson", jerseyNumber: 7, position: "SS")

            try await app.testing().test(.PUT, "api/v1/players/\(player.id)", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
                try req.content.encode(PlayerUpdateRequest(firstName: "Michael", lastName: "Johnson", jerseyNumber: 12, position: "2B"))
            }, afterResponse: { res async in
                #expect(res.status == .ok)
                let updated = try? res.content.decode(PlayerResponse.self)
                #expect(updated?.firstName == "Michael")
                #expect(updated?.jerseyNumber == 12)
                #expect(updated?.position == "2B")
            })

            try await cleanup(on: app.db)
        }
    }

    @Test func updatePlayerJerseyConflict() async throws {
        try await withApp(configure: configure) { app in
            try await cleanup(on: app.db)
            let token = try await loginAdmin(app: app)
            let team = try await createTeam(app: app, token: token, name: "PT UpdConflict", shortName: "PUC")
            try await createPlayer(app: app, token: token, teamId: team.id, firstName: "Mike", lastName: "Johnson", jerseyNumber: 7, position: "SS")
            let player2 = try await createPlayer(app: app, token: token, teamId: team.id, firstName: "Alex", lastName: "Smith", jerseyNumber: 12, position: "1B")

            try await app.testing().test(.PUT, "api/v1/players/\(player2.id)", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
                try req.content.encode(PlayerUpdateRequest(firstName: "Alex", lastName: "Smith", jerseyNumber: 7, position: "1B"))
            }, afterResponse: { res async in
                #expect(res.status == .conflict)
            })

            try await cleanup(on: app.db)
        }
    }

    @Test func updatePlayerKeepSameJersey() async throws {
        try await withApp(configure: configure) { app in
            try await cleanup(on: app.db)
            let token = try await loginAdmin(app: app)
            let team = try await createTeam(app: app, token: token, name: "PT SameJersey", shortName: "PSJ")
            let player = try await createPlayer(app: app, token: token, teamId: team.id, firstName: "Mike", lastName: "Johnson", jerseyNumber: 7, position: "SS")

            try await app.testing().test(.PUT, "api/v1/players/\(player.id)", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
                try req.content.encode(PlayerUpdateRequest(firstName: "Michael", lastName: "Johnson", jerseyNumber: 7, position: "SS"))
            }, afterResponse: { res async in
                #expect(res.status == .ok)
                let updated = try? res.content.decode(PlayerResponse.self)
                #expect(updated?.firstName == "Michael")
            })

            try await cleanup(on: app.db)
        }
    }

    @Test func updatePlayerNotFound() async throws {
        try await withApp(configure: configure) { app in
            let token = try await loginAdmin(app: app)

            try await app.testing().test(.PUT, "api/v1/players/\(UUID())", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
                try req.content.encode(PlayerUpdateRequest(firstName: "Mike", lastName: "Johnson", jerseyNumber: 7, position: "SS"))
            }, afterResponse: { res async in
                #expect(res.status == .notFound)
            })
        }
    }

    // MARK: - Delete (Soft)

    @Test func softDeletePlayer() async throws {
        try await withApp(configure: configure) { app in
            try await cleanup(on: app.db)
            let token = try await loginAdmin(app: app)
            let team = try await createTeam(app: app, token: token, name: "PT Delete", shortName: "PTD")
            let player = try await createPlayer(app: app, token: token, teamId: team.id, firstName: "Mike", lastName: "Johnson", jerseyNumber: 7, position: "SS")

            try await app.testing().test(.DELETE, "api/v1/players/\(player.id)", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
            }, afterResponse: { res async in
                #expect(res.status == .noContent)
            })

            // Should not appear in team's players
            try await app.testing().test(.GET, "api/v1/teams/\(team.id)/players", afterResponse: { res async in
                let players = try? res.content.decode([PlayerResponse].self)
                #expect(players?.isEmpty == true)
            })

            // Should still exist in DB (soft deleted)
            let softDeleted = try await Player.query(on: app.db)
                .withDeleted()
                .filter(\.$firstName, .equal, "Mike")
                .filter(\.$lastName, .equal, "Johnson")
                .first()
            #expect(softDeleted != nil)
            #expect(softDeleted?.deletedAt != nil)

            try await cleanup(on: app.db)
        }
    }

    @Test func deletePlayerNotFound() async throws {
        try await withApp(configure: configure) { app in
            let token = try await loginAdmin(app: app)

            try await app.testing().test(.DELETE, "api/v1/players/\(UUID())", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
            }, afterResponse: { res async in
                #expect(res.status == .notFound)
            })
        }
    }

    // MARK: - Team Detail includes players

    @Test func teamDetailIncludesPlayers() async throws {
        try await withApp(configure: configure) { app in
            try await cleanup(on: app.db)
            let token = try await loginAdmin(app: app)
            let team = try await createTeam(app: app, token: token, name: "PT Detail", shortName: "PDT")
            try await createPlayer(app: app, token: token, teamId: team.id, firstName: "Mike", lastName: "Johnson", jerseyNumber: 7, position: "SS")
            try await createPlayer(app: app, token: token, teamId: team.id, firstName: "Alex", lastName: "Adams", jerseyNumber: 12, position: "1B")

            try await app.testing().test(.GET, "api/v1/teams/\(team.id)", afterResponse: { res async in
                #expect(res.status == .ok)
                let detail = try? res.content.decode(TeamDetailResponse.self)
                #expect(detail?.players.count == 2)
                #expect(detail?.players.first?.lastName == "Adams")
            })

            try await cleanup(on: app.db)
        }
    }

    @Test func teamListIncludesPlayerCount() async throws {
        try await withApp(configure: configure) { app in
            try await cleanup(on: app.db)
            let token = try await loginAdmin(app: app)
            let team = try await createTeam(app: app, token: token, name: "PT Count", shortName: "PCN")
            try await createPlayer(app: app, token: token, teamId: team.id, firstName: "Mike", lastName: "Johnson", jerseyNumber: 7, position: "SS")

            try await app.testing().test(.GET, "api/v1/teams", afterResponse: { res async in
                #expect(res.status == .ok)
                let teams = try? res.content.decode([TeamResponse].self)
                let found = teams?.first { $0.name == "PT Count" }
                #expect(found?.playerCount == 1)
            })

            try await cleanup(on: app.db)
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

    @discardableResult
    private func createPlayer(app: Application, token: String, teamId: UUID, firstName: String, lastName: String, jerseyNumber: Int?, position: String?) async throws -> PlayerResponse {
        let res = try await app.testing().sendRequest(.POST, "api/v1/players", beforeRequest: { req in
            req.headers.bearerAuthorization = .init(token: token)
            try req.content.encode(PlayerRequest(firstName: firstName, lastName: lastName, jerseyNumber: jerseyNumber, position: position, teamId: teamId))
        })
        return try res.content.decode(PlayerResponse.self)
    }

    private func cleanup(on db: any Database) async throws {
        try await Player.query(on: db).withDeleted().delete(force: true)
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
