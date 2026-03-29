import Fluent
import Foundation
import BaseballShared

final class GameEvent: Model, @unchecked Sendable {
    static let schema = "game_events"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "game_id")
    var game: Game

    @Enum(key: "type")
    var type: GameEventType

    @OptionalField(key: "inning")
    var inning: Int?

    @OptionalEnum(key: "inning_half")
    var inningHalf: InningHalf?

    @OptionalField(key: "home_score")
    var homeScore: Int?

    @OptionalField(key: "away_score")
    var awayScore: Int?

    @OptionalField(key: "comment")
    var comment: String?

    @Parent(key: "created_by_id")
    var createdBy: User

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        gameID: UUID,
        type: GameEventType,
        inning: Int? = nil,
        inningHalf: InningHalf? = nil,
        homeScore: Int? = nil,
        awayScore: Int? = nil,
        comment: String? = nil,
        createdByID: UUID
    ) {
        self.id = id
        self.$game.id = gameID
        self.type = type
        self.inning = inning
        self.inningHalf = inningHalf
        self.homeScore = homeScore
        self.awayScore = awayScore
        self.comment = comment
        self.$createdBy.id = createdByID
    }

    func toResponse(user: User) -> GameEventResponse {
        GameEventResponse(
            id: id ?? UUID(),
            type: type,
            inning: inning,
            inningHalf: inningHalf,
            homeScore: homeScore,
            awayScore: awayScore,
            comment: comment,
            createdBy: user.toSummary(),
            createdAt: createdAt.map { ISO8601DateFormatter().string(from: $0) } ?? ""
        )
    }
}
