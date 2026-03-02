public struct PageMetadata: Codable, Sendable, Equatable {
    public let page: Int
    public let perPage: Int
    public let total: Int

    public init(page: Int, perPage: Int, total: Int) {
        self.page = page
        self.perPage = perPage
        self.total = total
    }
}
