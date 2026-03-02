public struct PaginatedResponse<T: Codable & Sendable & Equatable>: Codable, Sendable, Equatable {
    public let items: [T]
    public let metadata: PageMetadata

    public init(items: [T], metadata: PageMetadata) {
        self.items = items
        self.metadata = metadata
    }
}
