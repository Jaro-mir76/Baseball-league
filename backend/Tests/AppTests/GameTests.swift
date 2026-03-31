@testable import App
import VaporTesting
import Testing
import Fluent
import BaseballShared

@Suite(.serialized)
struct GameTests {

    // MARK: - List

    @Test func listGamesEmpty() async throws {
        try await withApp(configure: configure) { app in
            try await cleanup(on: app.db)
            let token = try await loginAdmin(app: app)
            try await createTeams(app: app, token: token)

            try await app.testing().test(.GET, "api/v1/games", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
            }, afterResponse: { res async in
                #expect(res.status == .ok)
                let page = try? res.content.decode(PaginatedResponse<GameResponse>.self)
                #expect(page?.items.isEmpty == true)
                #expect(page?.metadata.total == 0)
            })

            try await cleanup(on: app.db)
        }
    }

    @Test func listGamesReturnsCreatedGames() async throws {
        try await withApp(configure: configure) { app in
            try await cleanup(on: app.db)
            let token = try await loginAdmin(app: app)
            let (home, away) = try await createTeams(app: app, token: token)

            try await createGame(app: app, token: token, homeTeamId: home.id, awayTeamId: away.id, date: "2026-04-01")
            try await createGame(app: app, token: token, homeTeamId: away.id, awayTeamId: home.id, date: "2026-04-02")

            try await app.testing().test(.GET, "api/v1/games", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
            }, afterResponse: { res async in
                #expect(res.status == .ok)
                let page = try? res.content.decode(PaginatedResponse<GameResponse>.self)
                #expect(page?.items.count == 2)
                #expect(page?.metadata.total == 2)
                // Sorted by date descending
                #expect(page?.items.first?.date.contains("2026-04-02") == true)
            })

            try await cleanup(on: app.db)
        }
    }

    @Test func listGamesFilterByStatus() async throws {
        try await withApp(configure: configure) { app in
            try await cleanup(on: app.db)
            let token = try await loginAdmin(app: app)
            let (home, away) = try await createTeams(app: app, token: token)
            let scorer = try await createScorer(app: app, adminToken: token)

            let game = try await createGame(app: app, token: token, homeTeamId: home.id, awayTeamId: away.id, date: "2026-04-01")
            try await createGame(app: app, token: token, homeTeamId: away.id, awayTeamId: home.id, date: "2026-04-02")

            // Transition first game to live
            try await app.testing().test(.PATCH, "api/v1/games/\(game.id)/status", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: scorer)
                try req.content.encode(GameStatusUpdateRequest(status: .live))
            }, afterResponse: { res async in
                #expect(res.status == .ok)
            })

            try await app.testing().test(.GET, "api/v1/games?status=live", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
            }, afterResponse: { res async in
                #expect(res.status == .ok)
                let page = try? res.content.decode(PaginatedResponse<GameResponse>.self)
                #expect(page?.items.count == 1)
                #expect(page?.items.first?.status == .live)
            })

            try await cleanupScorer(on: app.db)
            try await cleanup(on: app.db)
        }
    }

    @Test func listGamesFilterByTeam() async throws {
        try await withApp(configure: configure) { app in
            try await cleanup(on: app.db)
            let token = try await loginAdmin(app: app)
            let (home, away) = try await createTeams(app: app, token: token)

            // Create a third team with a game
            let res = try await app.testing().sendRequest(.POST, "api/v1/teams", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
                try req.content.encode(TeamRequest(name: "GT Third", shortName: "GT3"))
            })
            let third = try res.content.decode(TeamResponse.self)

            try await createGame(app: app, token: token, homeTeamId: home.id, awayTeamId: away.id, date: "2026-04-01")
            try await createGame(app: app, token: token, homeTeamId: third.id, awayTeamId: away.id, date: "2026-04-02")

            try await app.testing().test(.GET, "api/v1/games?teamId=\(home.id)", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
            }, afterResponse: { res async in
                #expect(res.status == .ok)
                let page = try? res.content.decode(PaginatedResponse<GameResponse>.self)
                #expect(page?.items.count == 1)
            })

            try await cleanup(on: app.db)
        }
    }

    @Test func listGamesFilterByDateRange() async throws {
        try await withApp(configure: configure) { app in
            try await cleanup(on: app.db)
            let token = try await loginAdmin(app: app)
            let (home, away) = try await createTeams(app: app, token: token)

            try await createGame(app: app, token: token, homeTeamId: home.id, awayTeamId: away.id, date: "2026-03-15")
            try await createGame(app: app, token: token, homeTeamId: away.id, awayTeamId: home.id, date: "2026-04-01")
            try await createGame(app: app, token: token, homeTeamId: home.id, awayTeamId: away.id, date: "2026-04-15")

            try await app.testing().test(.GET, "api/v1/games?dateFrom=2026-04-01&dateTo=2026-04-10", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
            }, afterResponse: { res async in
                #expect(res.status == .ok)
                let page = try? res.content.decode(PaginatedResponse<GameResponse>.self)
                #expect(page?.items.count == 1)
            })

            try await cleanup(on: app.db)
        }
    }

    @Test func listGamesPagination() async throws {
        try await withApp(configure: configure) { app in
            try await cleanup(on: app.db)
            let token = try await loginAdmin(app: app)
            let (home, away) = try await createTeams(app: app, token: token)

            for i in 1...5 {
                try await createGame(app: app, token: token, homeTeamId: home.id, awayTeamId: away.id, date: "2026-04-0\(i)")
            }

            try await app.testing().test(.GET, "api/v1/games?page=1&perPage=2", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
            }, afterResponse: { res async in
                #expect(res.status == .ok)
                let page = try? res.content.decode(PaginatedResponse<GameResponse>.self)
                #expect(page?.items.count == 2)
                #expect(page?.metadata.total == 5)
                #expect(page?.metadata.page == 1)
                #expect(page?.metadata.perPage == 2)
            })

            try await app.testing().test(.GET, "api/v1/games?page=3&perPage=2", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
            }, afterResponse: { res async in
                #expect(res.status == .ok)
                let page = try? res.content.decode(PaginatedResponse<GameResponse>.self)
                #expect(page?.items.count == 1)
            })

            try await cleanup(on: app.db)
        }
    }

    // MARK: - Show

    @Test func showGame() async throws {
        try await withApp(configure: configure) { app in
            try await cleanup(on: app.db)
            let token = try await loginAdmin(app: app)
            let (home, away) = try await createTeams(app: app, token: token)
            let game = try await createGame(app: app, token: token, homeTeamId: home.id, awayTeamId: away.id, date: "2026-04-01", venue: "Central Park")

            try await app.testing().test(.GET, "api/v1/games/\(game.id)", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
            }, afterResponse: { res async in
                #expect(res.status == .ok)
                let detail = try? res.content.decode(GameResponse.self)
                #expect(detail?.homeTeam.name == "GT Home")
                #expect(detail?.awayTeam.name == "GT Away")
                #expect(detail?.status == .scheduled)
                #expect(detail?.homeScore == 0)
                #expect(detail?.awayScore == 0)
            })

            try await cleanup(on: app.db)
        }
    }

    @Test func showGameNotFound() async throws {
        try await withApp(configure: configure) { app in
            let token = try await loginAdmin(app: app)

            try await app.testing().test(.GET, "api/v1/games/\(UUID())", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
            }, afterResponse: { res async in
                #expect(res.status == .notFound)
            })
        }
    }

    // MARK: - Create

    @Test func createGameSuccess() async throws {
        try await withApp(configure: configure) { app in
            try await cleanup(on: app.db)
            let token = try await loginAdmin(app: app)
            let (home, away) = try await createTeams(app: app, token: token)

            try await app.testing().test(.POST, "api/v1/games", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
                try req.content.encode(GameRequest(homeTeamId: home.id, awayTeamId: away.id, date: "2026-04-01", scheduledTime: "2026-04-01T14:00:00Z", venue: "Central Park"))
            }, afterResponse: { res async in
                #expect(res.status == .created)
                let game = try? res.content.decode(GameResponse.self)
                #expect(game?.homeTeam.id == home.id)
                #expect(game?.awayTeam.id == away.id)
                #expect(game?.status == .scheduled)
                #expect(game?.homeScore == 0)
            })

            try await cleanup(on: app.db)
        }
    }

    @Test func createGameAsScorerAllowed() async throws {
        try await withApp(configure: configure) { app in
            try await cleanup(on: app.db)
            let token = try await loginAdmin(app: app)
            let (home, away) = try await createTeams(app: app, token: token)
            let scorer = try await createScorer(app: app, adminToken: token)

            try await app.testing().test(.POST, "api/v1/games", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: scorer)
                try req.content.encode(GameRequest(homeTeamId: home.id, awayTeamId: away.id, date: "2026-04-01", scheduledTime: nil, venue: nil))
            }, afterResponse: { res async in
                #expect(res.status == .created)
            })

            try await cleanupScorer(on: app.db)
            try await cleanup(on: app.db)
        }
    }

    @Test func createGameSameTeam() async throws {
        try await withApp(configure: configure) { app in
            try await cleanup(on: app.db)
            let token = try await loginAdmin(app: app)
            let (home, _) = try await createTeams(app: app, token: token)

            try await app.testing().test(.POST, "api/v1/games", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
                try req.content.encode(GameRequest(homeTeamId: home.id, awayTeamId: home.id, date: "2026-04-01", scheduledTime: nil, venue: nil))
            }, afterResponse: { res async in
                #expect(res.status == .unprocessableEntity)
            })

            try await cleanup(on: app.db)
        }
    }

    @Test func createGameTeamNotFound() async throws {
        try await withApp(configure: configure) { app in
            try await cleanup(on: app.db)
            let token = try await loginAdmin(app: app)
            let (home, _) = try await createTeams(app: app, token: token)

            try await app.testing().test(.POST, "api/v1/games", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
                try req.content.encode(GameRequest(homeTeamId: home.id, awayTeamId: UUID(), date: "2026-04-01", scheduledTime: nil, venue: nil))
            }, afterResponse: { res async in
                #expect(res.status == .notFound)
            })

            try await cleanup(on: app.db)
        }
    }

    @Test func createGameWithoutAuth() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.POST, "api/v1/games", beforeRequest: { req in
                try req.content.encode(GameRequest(homeTeamId: UUID(), awayTeamId: UUID(), date: "2026-04-01", scheduledTime: nil, venue: nil))
            }, afterResponse: { res async in
                #expect(res.status == .unauthorized)
            })
        }
    }

    @Test func createGameAsViewerForbidden() async throws {
        try await withApp(configure: configure) { app in
            try await cleanupUser(email: "viewer-game-test@test.com", on: app.db)
            let adminToken = try await loginAdmin(app: app)

            try await app.testing().test(.POST, "api/v1/auth/register", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: adminToken)
                try req.content.encode(RegisterRequest(email: "viewer-game-test@test.com", password: "password123", name: "Viewer", role: .viewer))
            }, afterResponse: { res async in
                #expect(res.status == .created)
            })

            let viewerLogin = try await loginFull(app: app, email: "viewer-game-test@test.com", password: "password123")

            try await app.testing().test(.POST, "api/v1/games", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: viewerLogin.accessToken)
                try req.content.encode(GameRequest(homeTeamId: UUID(), awayTeamId: UUID(), date: "2026-04-01", scheduledTime: nil, venue: nil))
            }, afterResponse: { res async in
                #expect(res.status == .forbidden)
            })

            try await cleanupUser(email: "viewer-game-test@test.com", on: app.db)
        }
    }

    @Test func createGameInvalidDate() async throws {
        try await withApp(configure: configure) { app in
            try await cleanup(on: app.db)
            let token = try await loginAdmin(app: app)
            let (home, away) = try await createTeams(app: app, token: token)

            try await app.testing().test(.POST, "api/v1/games", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
                try req.content.encode(GameRequest(homeTeamId: home.id, awayTeamId: away.id, date: "not-a-date", scheduledTime: nil, venue: nil))
            }, afterResponse: { res async in
                #expect(res.status == .badRequest)
            })

            try await cleanup(on: app.db)
        }
    }

    // MARK: - Status Transitions

    @Test func transitionScheduledToLive() async throws {
        try await withApp(configure: configure) { app in
            try await cleanup(on: app.db)
            let token = try await loginAdmin(app: app)
            let (home, away) = try await createTeams(app: app, token: token)
            let scorer = try await createScorer(app: app, adminToken: token)
            let game = try await createGame(app: app, token: token, homeTeamId: home.id, awayTeamId: away.id, date: "2026-04-01")

            try await app.testing().test(.PATCH, "api/v1/games/\(game.id)/status", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: scorer)
                try req.content.encode(GameStatusUpdateRequest(status: .live))
            }, afterResponse: { res async in
                #expect(res.status == .ok)
                let updated = try? res.content.decode(GameResponse.self)
                #expect(updated?.status == .live)
            })

            try await cleanupScorer(on: app.db)
            try await cleanup(on: app.db)
        }
    }

    @Test func transitionLiveToFinal() async throws {
        try await withApp(configure: configure) { app in
            try await cleanup(on: app.db)
            let token = try await loginAdmin(app: app)
            let (home, away) = try await createTeams(app: app, token: token)
            let scorer = try await createScorer(app: app, adminToken: token)
            let game = try await createGame(app: app, token: token, homeTeamId: home.id, awayTeamId: away.id, date: "2026-04-01")

            // scheduled -> live
            try await app.testing().test(.PATCH, "api/v1/games/\(game.id)/status", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: scorer)
                try req.content.encode(GameStatusUpdateRequest(status: .live))
            }, afterResponse: { res async in
                #expect(res.status == .ok)
            })

            // live -> final
            try await app.testing().test(.PATCH, "api/v1/games/\(game.id)/status", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: scorer)
                try req.content.encode(GameStatusUpdateRequest(status: .final))
            }, afterResponse: { res async in
                #expect(res.status == .ok)
                let updated = try? res.content.decode(GameResponse.self)
                #expect(updated?.status == .final)
            })

            try await cleanupScorer(on: app.db)
            try await cleanup(on: app.db)
        }
    }

    @Test func transitionScheduledToFinalRejected() async throws {
        try await withApp(configure: configure) { app in
            try await cleanup(on: app.db)
            let token = try await loginAdmin(app: app)
            let (home, away) = try await createTeams(app: app, token: token)
            let scorer = try await createScorer(app: app, adminToken: token)
            let game = try await createGame(app: app, token: token, homeTeamId: home.id, awayTeamId: away.id, date: "2026-04-01")

            try await app.testing().test(.PATCH, "api/v1/games/\(game.id)/status", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: scorer)
                try req.content.encode(GameStatusUpdateRequest(status: .final))
            }, afterResponse: { res async in
                #expect(res.status == .unprocessableEntity)
            })

            try await cleanupScorer(on: app.db)
            try await cleanup(on: app.db)
        }
    }

    @Test func transitionLiveToScheduledRejected() async throws {
        try await withApp(configure: configure) { app in
            try await cleanup(on: app.db)
            let token = try await loginAdmin(app: app)
            let (home, away) = try await createTeams(app: app, token: token)
            let scorer = try await createScorer(app: app, adminToken: token)
            let game = try await createGame(app: app, token: token, homeTeamId: home.id, awayTeamId: away.id, date: "2026-04-01")

            // scheduled -> live
            try await app.testing().test(.PATCH, "api/v1/games/\(game.id)/status", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: scorer)
                try req.content.encode(GameStatusUpdateRequest(status: .live))
            }, afterResponse: { res async in
                #expect(res.status == .ok)
            })

            // live -> scheduled (rejected)
            try await app.testing().test(.PATCH, "api/v1/games/\(game.id)/status", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: scorer)
                try req.content.encode(GameStatusUpdateRequest(status: .scheduled))
            }, afterResponse: { res async in
                #expect(res.status == .unprocessableEntity)
            })

            try await cleanupScorer(on: app.db)
            try await cleanup(on: app.db)
        }
    }

    @Test func transitionFinalRejected() async throws {
        try await withApp(configure: configure) { app in
            try await cleanup(on: app.db)
            let token = try await loginAdmin(app: app)
            let (home, away) = try await createTeams(app: app, token: token)
            let scorer = try await createScorer(app: app, adminToken: token)
            let game = try await createGame(app: app, token: token, homeTeamId: home.id, awayTeamId: away.id, date: "2026-04-01")

            // scheduled -> live -> final
            try await app.testing().test(.PATCH, "api/v1/games/\(game.id)/status", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: scorer)
                try req.content.encode(GameStatusUpdateRequest(status: .live))
            }, afterResponse: { _ async in })

            try await app.testing().test(.PATCH, "api/v1/games/\(game.id)/status", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: scorer)
                try req.content.encode(GameStatusUpdateRequest(status: .final))
            }, afterResponse: { _ async in })

            // final -> live (rejected)
            try await app.testing().test(.PATCH, "api/v1/games/\(game.id)/status", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: scorer)
                try req.content.encode(GameStatusUpdateRequest(status: .live))
            }, afterResponse: { res async in
                #expect(res.status == .unprocessableEntity)
            })

            try await cleanupScorer(on: app.db)
            try await cleanup(on: app.db)
        }
    }

    @Test func statusTransitionNotFound() async throws {
        try await withApp(configure: configure) { app in
            let token = try await loginAdmin(app: app)
            let scorer = try await createScorer(app: app, adminToken: token)

            try await app.testing().test(.PATCH, "api/v1/games/\(UUID())/status", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: scorer)
                try req.content.encode(GameStatusUpdateRequest(status: .live))
            }, afterResponse: { res async in
                #expect(res.status == .notFound)
            })

            try await cleanupScorer(on: app.db)
        }
    }

    // MARK: - Helpers

    private let scorerEmail = "scorer-game-test@test.com"

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

    private func createScorer(app: Application, adminToken: String) async throws -> String {
        try await cleanupUser(email: scorerEmail, on: app.db)

        try await app.testing().test(.POST, "api/v1/auth/register", beforeRequest: { req in
            req.headers.bearerAuthorization = .init(token: adminToken)
            try req.content.encode(RegisterRequest(email: scorerEmail, password: "password123", name: "Scorer", role: .scorer))
        }, afterResponse: { res async in
            #expect(res.status == .created)
        })

        let login = try await loginFull(app: app, email: scorerEmail, password: "password123")
        return login.accessToken
    }

    @discardableResult
    private func createTeams(app: Application, token: String) async throws -> (home: TeamResponse, away: TeamResponse) {
        let homeRes = try await app.testing().sendRequest(.POST, "api/v1/teams", beforeRequest: { req in
            req.headers.bearerAuthorization = .init(token: token)
            try req.content.encode(TeamRequest(name: "GT Home", shortName: "GTH"))
        })
        let home = try homeRes.content.decode(TeamResponse.self)

        let awayRes = try await app.testing().sendRequest(.POST, "api/v1/teams", beforeRequest: { req in
            req.headers.bearerAuthorization = .init(token: token)
            try req.content.encode(TeamRequest(name: "GT Away", shortName: "GTA"))
        })
        let away = try awayRes.content.decode(TeamResponse.self)

        return (home, away)
    }

    @discardableResult
    private func createGame(app: Application, token: String, homeTeamId: UUID, awayTeamId: UUID, date: String, venue: String? = nil) async throws -> GameResponse {
        let res = try await app.testing().sendRequest(.POST, "api/v1/games", beforeRequest: { req in
            req.headers.bearerAuthorization = .init(token: token)
            try req.content.encode(GameRequest(homeTeamId: homeTeamId, awayTeamId: awayTeamId, date: date, scheduledTime: nil, venue: venue))
        })
        return try res.content.decode(GameResponse.self)
    }

    private func cleanup(on db: any Database) async throws {
        try await Game.query(on: db).delete()
        try await Player.query(on: db).withDeleted().delete(force: true)
        try await Team.query(on: db).withDeleted().delete(force: true)
    }

    private func cleanupScorer(on db: any Database) async throws {
        try await cleanupUser(email: scorerEmail, on: db)
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
