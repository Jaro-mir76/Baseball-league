import Fluent

struct CreateGame: AsyncMigration {
    func prepare(on database: any Database) async throws {
        let gameStatus = try await database.enum("game_status")
            .case("scheduled")
            .case("live")
            .case("final")
            .create()

        try await database.schema("games")
            .id()
            .field("home_team_id", .uuid, .required, .references("teams", "id"))
            .field("away_team_id", .uuid, .required, .references("teams", "id"))
            .field("date", .date, .required)
            .field("scheduled_time", .datetime)
            .field("venue", .string)
            .field("status", gameStatus, .required, .sql(.default("scheduled")))
            .field("home_score", .int, .required, .sql(.default(0)))
            .field("away_score", .int, .required, .sql(.default(0)))
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .constraint(.custom("CHECK (home_team_id != away_team_id)"))
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("games").delete()
        try await database.enum("game_status").delete()
    }
}
