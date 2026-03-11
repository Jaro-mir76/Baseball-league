import Vapor
import FluentSQL
import BaseballShared

func routes(_ app: Application) throws {
    let api = app.grouped("api", "v1")
    try api.register(collection: AuthController())
    try api.register(collection: TeamController())

    app.get("health") { req async throws -> [String: String] in
        guard let sqlDB = req.db as? any SQLDatabase else {
            throw Abort(.internalServerError, reason: "Database does not support raw SQL")
        }
        do {
            try await sqlDB.raw("SELECT 1").run()
            return ["status": "ok"]
        }catch {
            return ["ERROR:": "\(String(reflecting: error))"]
        }
    }
}
