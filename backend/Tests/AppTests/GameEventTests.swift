@testable import App
import VaporTesting
import Testing
import Fluent
import BaseballShared

@Suite(.serialized)
struct GameEventTests {

    // MARK: - Post Score Event

    @Test func postScoreEvent() async throws {
        try await withApp(configure: configure) { app in
            try await cleanup(on: app.db)
            let (_, scorer, game) = try await setupLiveGame(app: app)

            try await app.testing().test(.POST, "api/v1/games/\(game.id)/events", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: scorer)
                try req.content.encode(GameEventRequest(type: .score, inning: 1, inningHalf: .top, homeScore: 0, awayScore: 2, comment: "Two-run homer"))
            }, afterResponse: { res async in
                #expect(res.status == .created)
                let event = try? res.content.decode(GameEventResponse.self)
                #expect(event?.type == .score)
                #expect(event?.inning == 1)
                #expect(event?.inningHalf == .top)
                #expect(event?.homeScore == 0)
                #expect(event?.awayScore == 2)
                #expect(event?.comment == "Two-run homer")
            })

            try await cleanup(on: app.db)
        }
    }

    @Test func postScoreUpdatesGameScores() async throws {
        try await withApp(configure: configure) { app in
            try await cleanup(on: app.db)
            let (_, scorer, game) = try await setupLiveGame(app: app)

            try await app.testing().test(.POST, "api/v1/games/\(game.id)/events", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: scorer)
                try req.content.encode(GameEventRequest(type: .score, inning: 1, inningHalf: .top, homeScore: 3, awayScore: 1, comment: nil))
            }, afterResponse: { _ async in })

            // Verify game scores updated
            try await app.testing().test(.GET, "api/v1/games/\(game.id)", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: scorer)
            }, afterResponse: { res async in
                #expect(res.status == .ok)
                let detail = try? res.content.decode(GameResponse.self)
                #expect(detail?.homeScore == 3)
                #expect(detail?.awayScore == 1)
            })

            try await cleanup(on: app.db)
        }
    }

    // MARK: - Post Comment Event

    @Test func postCommentEvent() async throws {
        try await withApp(configure: configure) { app in
            try await cleanup(on: app.db)
            let (_, scorer, game) = try await setupLiveGame(app: app)

            try await app.testing().test(.POST, "api/v1/games/\(game.id)/events", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: scorer)
                try req.content.encode(GameEventRequest(type: .comment, inning: 2, inningHalf: .bottom, homeScore: nil, awayScore: nil, comment: "Rain delay — 15 minutes"))
            }, afterResponse: { res async in
                #expect(res.status == .created)
                let event = try? res.content.decode(GameEventResponse.self)
                #expect(event?.type == .comment)
                #expect(event?.comment == "Rain delay — 15 minutes")
            })

            try await cleanup(on: app.db)
        }
    }

    // MARK: - Reject Non-Live Game

    @Test func rejectEventOnScheduledGame() async throws {
        try await withApp(configure: configure) { app in
            try await cleanup(on: app.db)
            let admin = try await loginAdmin(app: app)
            let scorer = try await createScorer(app: app, adminToken: admin)
            let (home, away) = try await createTeams(app: app, token: admin)
            let game = try await createGame(app: app, token: admin, homeTeamId: home.id, awayTeamId: away.id)

            try await app.testing().test(.POST, "api/v1/games/\(game.id)/events", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: scorer)
                try req.content.encode(GameEventRequest(type: .score, inning: 1, inningHalf: .top, homeScore: 1, awayScore: 0, comment: nil))
            }, afterResponse: { res async in
                #expect(res.status == .unprocessableEntity)
            })

            try await cleanup(on: app.db)
        }
    }

    @Test func rejectEventOnFinalGame() async throws {
        try await withApp(configure: configure) { app in
            try await cleanup(on: app.db)
            let (_, scorer, game) = try await setupLiveGame(app: app)

            // Transition to final
            try await app.testing().test(.PATCH, "api/v1/games/\(game.id)/status", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: scorer)
                try req.content.encode(GameStatusUpdateRequest(status: .final))
            }, afterResponse: { _ async in })

            try await app.testing().test(.POST, "api/v1/games/\(game.id)/events", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: scorer)
                try req.content.encode(GameEventRequest(type: .score, inning: 1, inningHalf: .top, homeScore: 1, awayScore: 0, comment: nil))
            }, afterResponse: { res async in
                #expect(res.status == .unprocessableEntity)
            })

            try await cleanup(on: app.db)
        }
    }

    // MARK: - Validation

    @Test func rejectScoreWithoutInning() async throws {
        try await withApp(configure: configure) { app in
            try await cleanup(on: app.db)
            let (_, scorer, game) = try await setupLiveGame(app: app)

            try await app.testing().test(.POST, "api/v1/games/\(game.id)/events", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: scorer)
                try req.content.encode(GameEventRequest(type: .score, inning: nil, inningHalf: .top, homeScore: 1, awayScore: 0, comment: nil))
            }, afterResponse: { res async in
                #expect(res.status == .badRequest)
            })

            try await cleanup(on: app.db)
        }
    }

    @Test func rejectCommentWithoutText() async throws {
        try await withApp(configure: configure) { app in
            try await cleanup(on: app.db)
            let (_, scorer, game) = try await setupLiveGame(app: app)

            try await app.testing().test(.POST, "api/v1/games/\(game.id)/events", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: scorer)
                try req.content.encode(GameEventRequest(type: .comment, inning: nil, inningHalf: nil, homeScore: nil, awayScore: nil, comment: nil))
            }, afterResponse: { res async in
                #expect(res.status == .badRequest)
            })

            try await cleanup(on: app.db)
        }
    }

    @Test func rejectNegativeScore() async throws {
        try await withApp(configure: configure) { app in
            try await cleanup(on: app.db)
            let (_, scorer, game) = try await setupLiveGame(app: app)

            try await app.testing().test(.POST, "api/v1/games/\(game.id)/events", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: scorer)
                try req.content.encode(GameEventRequest(type: .score, inning: 1, inningHalf: .top, homeScore: -1, awayScore: 0, comment: nil))
            }, afterResponse: { res async in
                #expect(res.status == .badRequest)
            })

            try await cleanup(on: app.db)
        }
    }

    // MARK: - List Events

    @Test func listEventsChronological() async throws {
        try await withApp(configure: configure) { app in
            try await cleanup(on: app.db)
            let (_, scorer, game) = try await setupLiveGame(app: app)

            // Add two events
            try await app.testing().test(.POST, "api/v1/games/\(game.id)/events", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: scorer)
                try req.content.encode(GameEventRequest(type: .score, inning: 1, inningHalf: .top, homeScore: 0, awayScore: 1, comment: nil))
            }, afterResponse: { _ async in })

            try await app.testing().test(.POST, "api/v1/games/\(game.id)/events", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: scorer)
                try req.content.encode(GameEventRequest(type: .score, inning: 1, inningHalf: .bottom, homeScore: 2, awayScore: 1, comment: nil))
            }, afterResponse: { _ async in })

            try await app.testing().test(.GET, "api/v1/games/\(game.id)/events", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: scorer)
            }, afterResponse: { res async in
                #expect(res.status == .ok)
                let events = try? res.content.decode([GameEventResponse].self)
                #expect(events?.count == 2)
                #expect(events?.first?.inningHalf == .top)
                #expect(events?.last?.inningHalf == .bottom)
            })

            try await cleanup(on: app.db)
        }
    }

    @Test func listEventsGameNotFound() async throws {
        try await withApp(configure: configure) { app in
            let token = try await loginAdmin(app: app)

            try await app.testing().test(.GET, "api/v1/games/\(UUID())/events", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
            }, afterResponse: { res async in
                #expect(res.status == .notFound)
            })
        }
    }

    // MARK: - Delete Last Event

    @Test func deleteLastEvent() async throws {
        try await withApp(configure: configure) { app in
            try await cleanup(on: app.db)
            let (_, scorer, game) = try await setupLiveGame(app: app)

            // Add two score events
            try await app.testing().test(.POST, "api/v1/games/\(game.id)/events", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: scorer)
                try req.content.encode(GameEventRequest(type: .score, inning: 1, inningHalf: .top, homeScore: 0, awayScore: 2, comment: nil))
            }, afterResponse: { _ async in })

            var secondEventId: UUID!
            try await app.testing().test(.POST, "api/v1/games/\(game.id)/events", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: scorer)
                try req.content.encode(GameEventRequest(type: .score, inning: 1, inningHalf: .bottom, homeScore: 3, awayScore: 2, comment: nil))
            }, afterResponse: { res async in
                let event = try? res.content.decode(GameEventResponse.self)
                secondEventId = event?.id
            })

            // Delete the second (most recent) event
            try await app.testing().test(.DELETE, "api/v1/games/\(game.id)/events/\(secondEventId!)", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: scorer)
            }, afterResponse: { res async in
                #expect(res.status == .noContent)
            })

            // Scores should revert to first event's scores
            try await app.testing().test(.GET, "api/v1/games/\(game.id)", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: scorer)
            }, afterResponse: { res async in
                let detail = try? res.content.decode(GameResponse.self)
                #expect(detail?.homeScore == 0)
                #expect(detail?.awayScore == 2)
            })

            // Only one event should remain
            try await app.testing().test(.GET, "api/v1/games/\(game.id)/events", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: scorer)
            }, afterResponse: { res async in
                let events = try? res.content.decode([GameEventResponse].self)
                #expect(events?.count == 1)
            })

            try await cleanup(on: app.db)
        }
    }

    @Test func deleteNonLastEventRejected() async throws {
        try await withApp(configure: configure) { app in
            try await cleanup(on: app.db)
            let (_, scorer, game) = try await setupLiveGame(app: app)

            var firstEventId: UUID!
            try await app.testing().test(.POST, "api/v1/games/\(game.id)/events", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: scorer)
                try req.content.encode(GameEventRequest(type: .score, inning: 1, inningHalf: .top, homeScore: 0, awayScore: 1, comment: nil))
            }, afterResponse: { res async in
                let event = try? res.content.decode(GameEventResponse.self)
                firstEventId = event?.id
            })

            try await app.testing().test(.POST, "api/v1/games/\(game.id)/events", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: scorer)
                try req.content.encode(GameEventRequest(type: .score, inning: 1, inningHalf: .bottom, homeScore: 2, awayScore: 1, comment: nil))
            }, afterResponse: { _ async in })

            // Try to delete first event (not the most recent)
            try await app.testing().test(.DELETE, "api/v1/games/\(game.id)/events/\(firstEventId!)", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: scorer)
            }, afterResponse: { res async in
                #expect(res.status == .conflict)
            })

            try await cleanup(on: app.db)
        }
    }

    @Test func deleteAllEventsResetsScores() async throws {
        try await withApp(configure: configure) { app in
            try await cleanup(on: app.db)
            let (_, scorer, game) = try await setupLiveGame(app: app)

            var eventId: UUID!
            try await app.testing().test(.POST, "api/v1/games/\(game.id)/events", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: scorer)
                try req.content.encode(GameEventRequest(type: .score, inning: 1, inningHalf: .top, homeScore: 5, awayScore: 3, comment: nil))
            }, afterResponse: { res async in
                let event = try? res.content.decode(GameEventResponse.self)
                eventId = event?.id
            })

            try await app.testing().test(.DELETE, "api/v1/games/\(game.id)/events/\(eventId!)", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: scorer)
            }, afterResponse: { res async in
                #expect(res.status == .noContent)
            })

            // Scores should be 0-0
            try await app.testing().test(.GET, "api/v1/games/\(game.id)", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: scorer)
            }, afterResponse: { res async in
                let detail = try? res.content.decode(GameResponse.self)
                #expect(detail?.homeScore == 0)
                #expect(detail?.awayScore == 0)
            })

            try await cleanup(on: app.db)
        }
    }

    // MARK: - Auth

    @Test func postEventWithoutAuth() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.POST, "api/v1/games/\(UUID())/events", beforeRequest: { req in
                try req.content.encode(GameEventRequest(type: .score, inning: 1, inningHalf: .top, homeScore: 1, awayScore: 0, comment: nil))
            }, afterResponse: { res async in
                #expect(res.status == .unauthorized)
            })
        }
    }

    @Test func postEventGameNotFound() async throws {
        try await withApp(configure: configure) { app in
            try await cleanup(on: app.db)
            let admin = try await loginAdmin(app: app)
            let scorer = try await createScorer(app: app, adminToken: admin)

            try await app.testing().test(.POST, "api/v1/games/\(UUID())/events", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: scorer)
                try req.content.encode(GameEventRequest(type: .score, inning: 1, inningHalf: .top, homeScore: 1, awayScore: 0, comment: nil))
            }, afterResponse: { res async in
                #expect(res.status == .notFound)
            })

            try await cleanupScorer(on: app.db)
        }
    }

    // MARK: - Helpers

    private let scorerEmail = "scorer-event-test@test.com"

    /// Sets up a live game and returns (adminToken, scorerToken, game)
    private func setupLiveGame(app: Application) async throws -> (String, String, GameResponse) {
        let admin = try await loginAdmin(app: app)
        let scorer = try await createScorer(app: app, adminToken: admin)
        let (home, away) = try await createTeams(app: app, token: admin)
        let game = try await createGame(app: app, token: admin, homeTeamId: home.id, awayTeamId: away.id)

        // Transition to live
        let res = try await app.testing().sendRequest(.PATCH, "api/v1/games/\(game.id)/status", beforeRequest: { req in
            req.headers.bearerAuthorization = .init(token: scorer)
            try req.content.encode(GameStatusUpdateRequest(status: .live))
        })
        let liveGame = try res.content.decode(GameResponse.self)

        return (admin, scorer, liveGame)
    }

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
            try req.content.encode(TeamRequest(name: "GE Home", shortName: "GEH"))
        })
        let home = try homeRes.content.decode(TeamResponse.self)

        let awayRes = try await app.testing().sendRequest(.POST, "api/v1/teams", beforeRequest: { req in
            req.headers.bearerAuthorization = .init(token: token)
            try req.content.encode(TeamRequest(name: "GE Away", shortName: "GEA"))
        })
        let away = try awayRes.content.decode(TeamResponse.self)

        return (home, away)
    }

    @discardableResult
    private func createGame(app: Application, token: String, homeTeamId: UUID, awayTeamId: UUID) async throws -> GameResponse {
        let res = try await app.testing().sendRequest(.POST, "api/v1/games", beforeRequest: { req in
            req.headers.bearerAuthorization = .init(token: token)
            try req.content.encode(GameRequest(homeTeamId: homeTeamId, awayTeamId: awayTeamId, date: "2026-04-15", scheduledTime: nil, venue: nil))
        })
        return try res.content.decode(GameResponse.self)
    }

    private func cleanup(on db: any Database) async throws {
        try await GameEvent.query(on: db).delete()
        try await Game.query(on: db).delete()
        try await Player.query(on: db).withDeleted().delete(force: true)
        try await Team.query(on: db).withDeleted().delete(force: true)
        try await cleanupScorer(on: db)
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
