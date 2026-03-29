import Fluent

struct CreateGameEvent: AsyncMigration {
    func prepare(on database: any Database) async throws {
        let eventType = try await database.enum("game_event_type")
            .case("score")
            .case("comment")
            .create()

        let inningHalf = try await database.enum("inning_half")
            .case("top")
            .case("bottom")
            .create()

        try await database.schema("game_events")
            .id()
            .field("game_id", .uuid, .required, .references("games", "id"))
            .field("type", eventType, .required)
            .field("inning", .int)
            .field("inning_half", inningHalf)
            .field("home_score", .int)
            .field("away_score", .int)
            .field("comment", .string)
            .field("created_by_id", .uuid, .required, .references("users", "id"))
            .field("created_at", .datetime)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("game_events").delete()
        try await database.enum("inning_half").delete()
        try await database.enum("game_event_type").delete()
    }
}
