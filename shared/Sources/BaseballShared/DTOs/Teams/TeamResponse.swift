import Foundation

public struct TeamResponse: Codable, Sendable, Equatable {
    public let id: UUID
    public let name: String
    public let shortName: String?
    public let playerCount: Int
    public let createdAt: String

    public init(id: UUID, name: String, shortName: String?, playerCount: Int, createdAt: String) {
        self.id = id
        self.name = name
        self.shortName = shortName
        self.playerCount = playerCount
        self.createdAt = createdAt
    }
}
