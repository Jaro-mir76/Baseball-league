import Foundation

public struct GameRequest: Codable, Sendable, Equatable {
    public let homeTeamId: UUID
    public let awayTeamId: UUID
    public let date: String
    public let scheduledTime: String?
    public let venue: String?

    public init(homeTeamId: UUID, awayTeamId: UUID, date: String, scheduledTime: String?, venue: String?) {
        self.homeTeamId = homeTeamId
        self.awayTeamId = awayTeamId
        self.date = date
        self.scheduledTime = scheduledTime
        self.venue = venue
    }
}
