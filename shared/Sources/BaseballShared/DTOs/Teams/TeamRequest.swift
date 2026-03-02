public struct TeamRequest: Codable, Sendable, Equatable {
    public let name: String
    public let shortName: String?

    public init(name: String, shortName: String?) {
        self.name = name
        self.shortName = shortName
    }
}
