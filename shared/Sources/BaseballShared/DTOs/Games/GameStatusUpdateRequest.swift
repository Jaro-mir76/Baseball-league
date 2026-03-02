public struct GameStatusUpdateRequest: Codable, Sendable, Equatable {
    public let status: GameStatus

    public init(status: GameStatus) {
        self.status = status
    }
}
