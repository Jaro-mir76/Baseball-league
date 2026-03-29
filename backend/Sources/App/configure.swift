import Vapor
import Fluent
import FluentPostgresDriver
import JWT

func configure(_ app: Application) async throws {

    // JWT signing key
    let jwtSecret = Environment.get("JWT_SECRET") ?? "dev-secret-change-in-production"
    app.jwt.signers.use(.hs256(key: jwtSecret))

    let dbConfig = SQLPostgresConfiguration(
        hostname: Environment.get("POSTGRES_HOST") ?? "localhost",
        port: Environment.get("POSTGRES_PORT").flatMap(Int.init) ?? SQLPostgresConfiguration.ianaPortNumber,
        username: Environment.get("POSTGRES_USER") ?? "user",
        password: Environment.get("POSTGRES_PASSWORD") ?? "password",
        database: Environment.get("POSTGRES_DB") ?? "db_name",
        tls: .disable
    )
    
    app.databases.use(.postgres(configuration: dbConfig), as: .psql)

    app.migrations.add(CreateUser())
    app.migrations.add(CreateRefreshToken())
    app.migrations.add(SeedAdminUser())
    app.migrations.add(CreateTeam())
    app.migrations.add(CreatePlayer())
    app.migrations.add(CreateGame())
    app.migrations.add(CreateGameEvent())

    try await app.autoMigrate()

    try routes(app)
}
