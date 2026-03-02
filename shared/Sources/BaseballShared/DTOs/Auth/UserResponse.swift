import Foundation

public struct UserResponse: Codable, Sendable, Equatable {
    public let id: UUID
    public let email: String
    public let name: String
    public let role: UserRole
    public let createdAt: String?

    public init(id: UUID, email: String, name: String, role: UserRole, createdAt: String?) {
        self.id = id
        self.email = email
        self.name = name
        self.role = role
        self.createdAt = createdAt
    }
}
