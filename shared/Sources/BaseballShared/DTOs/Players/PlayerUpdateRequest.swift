public struct PlayerUpdateRequest: Codable, Sendable, Equatable {
    public let firstName: String
    public let lastName: String
    public let jerseyNumber: Int?
    public let position: String?

    public init(firstName: String, lastName: String, jerseyNumber: Int?, position: String?) {
        self.firstName = firstName
        self.lastName = lastName
        self.jerseyNumber = jerseyNumber
        self.position = position
    }
}
