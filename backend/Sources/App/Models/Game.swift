import Fluent
import Foundation
import BaseballShared

final class Game: Model, @unchecked Sendable {
    static let schema = "games"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "home_team_id")
    var homeTeam: Team

    @Parent(key: "away_team_id")
    var awayTeam: Team

    @Field(key: "date")
    var date: Date

    @OptionalField(key: "scheduled_time")
    var scheduledTime: Date?

    @OptionalField(key: "venue")
    var venue: String?

    @Enum(key: "status")
    var status: GameStatus

    @Field(key: "home_score")
    var homeScore: Int

    @Field(key: "away_score")
    var awayScore: Int

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        homeTeamID: UUID,
        awayTeamID: UUID,
        date: Date,
        scheduledTime: Date? = nil,
        venue: String? = nil,
        status: GameStatus = .scheduled,
        homeScore: Int = 0,
        awayScore: Int = 0
    ) {
        self.id = id
        self.$homeTeam.id = homeTeamID
        self.$awayTeam.id = awayTeamID
        self.date = date
        self.scheduledTime = scheduledTime
        self.venue = venue
        self.status = status
        self.homeScore = homeScore
        self.awayScore = awayScore
    }

    func toResponse(homeTeam: Team, awayTeam: Team) -> GameResponse {
        GameResponse(
            id: id ?? UUID(),
            homeTeam: homeTeam.toSummary(),
            awayTeam: awayTeam.toSummary(),
            date: ISO8601DateFormatter().string(from: date),
            status: status,
            homeScore: homeScore,
            awayScore: awayScore,
            createdAt: createdAt.map { ISO8601DateFormatter().string(from: $0) }
        )
    }
}

extension Team {
    func toSummary() -> TeamSummary {
        TeamSummary(id: id ?? UUID(), name: name, shortName: shortName)
    }
}
