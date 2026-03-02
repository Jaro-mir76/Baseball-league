public struct RegisterRequest: Codable, Sendable, Equatable {
    public let email: String
    public let password: String
    public let name: String
    public let role: UserRole

    public init(email: String, password: String, name: String, role: UserRole) {
        self.email = email
        self.password = password
        self.name = name
        self.role = role
    }
}
