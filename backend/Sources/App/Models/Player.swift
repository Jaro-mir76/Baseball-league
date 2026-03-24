import Fluent
import Foundation
import BaseballShared

final class Player: Model, @unchecked Sendable {
    static let schema = "players"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "first_name")
    var firstName: String

    @Field(key: "last_name")
    var lastName: String

    @OptionalField(key: "jersey_number")
    var jerseyNumber: Int?

    @OptionalField(key: "position")
    var position: String?

    @Parent(key: "team_id")
    var team: Team

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Timestamp(key: "deleted_at", on: .delete)
    var deletedAt: Date?

    init() {}

    init(id: UUID? = nil, firstName: String, lastName: String, jerseyNumber: Int? = nil, position: String? = nil, teamID: UUID) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.jerseyNumber = jerseyNumber
        self.position = position
        self.$team.id = teamID
    }

    func toResponse() -> PlayerResponse {
        PlayerResponse(
            id: id ?? UUID(),
            firstName: firstName,
            lastName: lastName,
            jerseyNumber: jerseyNumber,
            position: position,
            teamId: $team.id,
            createdAt: createdAt.map { ISO8601DateFormatter().string(from: $0) } ?? ""
        )
    }

    func toSummary() -> PlayerSummary {
        PlayerSummary(
            id: id ?? UUID(),
            firstName: firstName,
            lastName: lastName,
            jerseyNumber: jerseyNumber,
            position: position
        )
    }
}
