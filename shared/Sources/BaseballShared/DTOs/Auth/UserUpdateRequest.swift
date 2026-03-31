public struct UserUpdateRequest: Codable, Sendable, Equatable {
    public let name: String
    public let role: UserRole

    public init(name: String, role: UserRole) {
        self.name = name
        self.role = role
    }
}
