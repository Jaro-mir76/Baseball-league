public struct GameEventRequest: Codable, Sendable, Equatable {
    public let type: GameEventType
    public let inning: Int?
    public let inningHalf: InningHalf?
    public let homeScore: Int?
    public let awayScore: Int?
    public let comment: String?

    public init(type: GameEventType, inning: Int?, inningHalf: InningHalf?, homeScore: Int?, awayScore: Int?, comment: String?) {
        self.type = type
        self.inning = inning
        self.inningHalf = inningHalf
        self.homeScore = homeScore
        self.awayScore = awayScore
        self.comment = comment
    }
}
