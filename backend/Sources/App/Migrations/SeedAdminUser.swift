import Vapor
import Fluent
import BaseballShared

struct SeedAdminUser: AsyncMigration {
    func prepare(on database: any Database) async throws {
        let email = Environment.get("ADMIN_EMAIL") ?? "admin@baseball.local"
        let password = Environment.get("ADMIN_PASSWORD") ?? "adminPassword"
        let name = Environment.get("ADMIN_NAME") ?? "Admin"

        let passwordHash = try Bcrypt.hash(password)
        let admin = User(
            email: email.lowercased().trimmingCharacters(in: .whitespaces),
            passwordHash: passwordHash,
            name: name,
            role: .admin
        )
        try await admin.save(on: database)
    }

    func revert(on database: any Database) async throws {
        let email = Environment.get("ADMIN_EMAIL") ?? "admin@baseball.local"
        try await User.query(on: database)
            .filter(\.$email == email)
            .delete()
    }
}
