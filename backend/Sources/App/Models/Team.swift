import Fluent
import Foundation
import BaseballShared

final class Team: Model, @unchecked Sendable {
    static let schema = "teams"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @OptionalField(key: "short_name")
    var shortName: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Timestamp(key: "deleted_at", on: .delete)
    var deletedAt: Date?

    init() {}

    init(id: UUID? = nil, name: String, shortName: String? = nil) {
        self.id = id
        self.name = name
        self.shortName = shortName
    }

    func toResponse(playerCount: Int = 0) -> TeamResponse {
        TeamResponse(
            id: id ?? UUID(),
            name: name,
            shortName: shortName,
            playerCount: playerCount,
            createdAt: createdAt.map { ISO8601DateFormatter().string(from: $0) } ?? ""
        )
    }
}
