import Fluent
import Foundation
import BaseballShared

final class User: Model, @unchecked Sendable {
    static let schema = "users"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "email")
    var email: String

    @Field(key: "password_hash")
    var passwordHash: String

    @Field(key: "name")
    var name: String

    @Enum(key: "role")
    var role: UserRole

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Timestamp(key: "deleted_at", on: .delete)
    var deletedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        email: String,
        passwordHash: String,
        name: String,
        role: UserRole
    ) {
        self.id = id
        self.email = email
        self.passwordHash = passwordHash
        self.name = name
        self.role = role
    }

    func toResponse() -> UserResponse {
        let createdAtString: String?
        if let createdAt {
            createdAtString = ISO8601DateFormatter().string(from: createdAt)
        } else {
            createdAtString = nil
        }
        return UserResponse(
            id: id ?? UUID(),
            email: email,
            name: name,
            role: role,
            createdAt: createdAtString
        )
    }
}
