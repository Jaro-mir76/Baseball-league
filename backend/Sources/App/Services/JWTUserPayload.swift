import JWTKit
import Foundation
import BaseballShared

struct JWTUserPayload: JWTPayload {
    var sub: SubjectClaim
    var exp: ExpirationClaim
    var role: UserRole
    var name: String

    func verify(using signer: JWTSigner) throws {
        try exp.verifyNotExpired()
    }

    init(userID: UUID, role: UserRole, name: String, expiresAt: Date) {
        self.sub = .init(value: userID.uuidString)
        self.exp = .init(value: expiresAt)
        self.role = role
        self.name = name
    }

    var userID: UUID? {
        UUID(uuidString: sub.value)
    }
}
