import Foundation

public struct PlayerSummary: Codable, Sendable, Equatable {
    public let id: UUID
    public let firstName: String
    public let lastName: String
    public let jerseyNumber: Int?
    public let position: String?

    public init(id: UUID, firstName: String, lastName: String, jerseyNumber: Int?, position: String?) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.jerseyNumber = jerseyNumber
        self.position = position
    }
}
