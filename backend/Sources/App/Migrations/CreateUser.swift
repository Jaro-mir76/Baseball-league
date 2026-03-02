import Fluent
import BaseballShared

struct CreateUser: AsyncMigration {
    func prepare(on database: any Database) async throws {
        let userRole = try await database.enum("user_role")
            .case("admin")
            .case("scorer")
            .case("viewer")
            .create()

        try await database.schema("users")
            .id()
            .field("email", .string, .required)
            .field("password_hash", .string, .required)
            .field("name", .string, .required)
            .field("role", userRole, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .field("deleted_at", .datetime)
            .unique(on: "email")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("users").delete()
        try await database.enum("user_role").delete()
    }
}
