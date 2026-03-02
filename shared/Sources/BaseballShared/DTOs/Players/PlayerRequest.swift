import Foundation

public struct PlayerRequest: Codable, Sendable, Equatable {
    public let firstName: String
    public let lastName: String
    public let jerseyNumber: Int?
    public let position: String?
    public let teamId: UUID

    public init(firstName: String, lastName: String, jerseyNumber: Int?, position: String?, teamId: UUID) {
        self.firstName = firstName
        self.lastName = lastName
        self.jerseyNumber = jerseyNumber
        self.position = position
        self.teamId = teamId
    }
}
