public struct TokenResponse: Codable, Sendable, Equatable {
    public let accessToken: String
    public let refreshToken: String
    public let user: UserResponse?

    public init(accessToken: String, refreshToken: String, user: UserResponse?) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.user = user
    }
}
