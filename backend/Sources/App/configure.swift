import Vapor
import Fluent
import FluentPostgresDriver

func configure(_ app: Application) async throws {
        
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

    try await app.autoMigrate()

    try routes(app)
}
