import Foundation

public struct TeamSummary: Codable, Sendable, Equatable {
    public let id: UUID
    public let name: String
    public let shortName: String?

    public init(id: UUID, name: String, shortName: String?) {
        self.id = id
        self.name = name
        self.shortName = shortName
    }
}
