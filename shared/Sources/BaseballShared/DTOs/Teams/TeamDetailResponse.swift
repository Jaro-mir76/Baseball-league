import Foundation

public struct TeamDetailResponse: Codable, Sendable, Equatable {
    public let id: UUID
    public let name: String
    public let shortName: String?
    public let players: [PlayerSummary]
    public let createdAt: String

    public init(id: UUID, name: String, shortName: String?, players: [PlayerSummary], createdAt: String) {
        self.id = id
        self.name = name
        self.shortName = shortName
        self.players = players
        self.createdAt = createdAt
    }
}
