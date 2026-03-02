import Foundation

public struct PlayerResponse: Codable, Sendable, Equatable {
    public let id: UUID
    public let firstName: String
    public let lastName: String
    public let jerseyNumber: Int?
    public let position: String?
    public let teamId: UUID
    public let createdAt: String

    public init(id: UUID, firstName: String, lastName: String, jerseyNumber: Int?, position: String?, teamId: UUID, createdAt: String) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.jerseyNumber = jerseyNumber
        self.position = position
        self.teamId = teamId
        self.createdAt = createdAt
    }
}
