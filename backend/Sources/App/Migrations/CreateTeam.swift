import Fluent

struct CreateTeam: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("teams")
            .id()
            .field("name", .string, .required)
            .field("short_name", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .field("deleted_at", .datetime)
            .unique(on: "name")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("teams").delete()
    }
}
