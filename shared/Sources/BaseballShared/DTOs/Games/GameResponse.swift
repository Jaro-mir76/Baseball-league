import Foundation

public struct GameResponse: Codable, Sendable, Equatable {
    public let id: UUID
    public let homeTeam: TeamSummary
    public let awayTeam: TeamSummary
    public let date: String
    public let status: GameStatus
    public let homeScore: Int
    public let awayScore: Int
    public let createdAt: String?

    public init(id: UUID, homeTeam: TeamSummary, awayTeam: TeamSummary, date: String, status: GameStatus, homeScore: Int, awayScore: Int, createdAt: String?) {
        self.id = id
        self.homeTeam = homeTeam
        self.awayTeam = awayTeam
        self.date = date
        self.status = status
        self.homeScore = homeScore
        self.awayScore = awayScore
        self.createdAt = createdAt
    }
}
