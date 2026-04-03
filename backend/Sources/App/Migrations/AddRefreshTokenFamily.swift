import Fluent

struct AddRefreshTokenFamily: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("refresh_tokens")
            .field("family", .uuid)
            .field("is_revoked", .bool, .sql(.default(false)))
            .update()

        // Backfill existing tokens with unique family IDs
        let tokens = try await RefreshToken.query(on: database).all()
        for token in tokens {
            token.family = UUID()
            token.isRevoked = false
            try await token.save(on: database)
        }
    }

    func revert(on database: any Database) async throws {
        try await database.schema("refresh_tokens")
            .deleteField("family")
            .deleteField("is_revoked")
            .update()
    }
}
