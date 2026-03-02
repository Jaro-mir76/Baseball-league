import Foundation

public struct GameEventResponse: Codable, Sendable, Equatable {
    public let id: UUID
    public let type: GameEventType
    public let inning: Int?
    public let inningHalf: InningHalf?
    public let homeScore: Int?
    public let awayScore: Int?
    public let comment: String?
    public let createdBy: UserSummary
    public let createdAt: String

    public init(id: UUID, type: GameEventType, inning: Int?, inningHalf: InningHalf?, homeScore: Int?, awayScore: Int?, comment: String?, createdBy: UserSummary, createdAt: String) {
        self.id = id
        self.type = type
        self.inning = inning
        self.inningHalf = inningHalf
        self.homeScore = homeScore
        self.awayScore = awayScore
        self.comment = comment
        self.createdBy = createdBy
        self.createdAt = createdAt
    }
}
