public struct ErrorResponse: Codable, Sendable, Equatable {
    public let error: Bool
    public let reason: String

    public init(error: Bool, reason: String) {
        self.error = error
        self.reason = reason
    }
}
