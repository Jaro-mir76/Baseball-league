import Fluent

struct CreatePlayer: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("players")
            .id()
            .field("first_name", .string, .required)
            .field("last_name", .string, .required)
            .field("jersey_number", .int)
            .field("position", .string)
            .field("team_id", .uuid, .required, .references("teams", "id"))
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .field("deleted_at", .datetime)
            .unique(on: "team_id", "jersey_number")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("players").delete()
    }
}
