import Foundation

public struct GameFilterRequest: Codable, Sendable, Equatable {
    public let status: GameStatus?
    public let teamId: UUID?
    public let dateFrom: String?
    public let dateTo: String?
    public let page: Int?
    public let perPage: Int?

    public init(status: GameStatus?, teamId: UUID?, dateFrom: String?, dateTo: String?, page: Int?, perPage: Int?) {
        self.status = status
        self.teamId = teamId
        self.dateFrom = dateFrom
        self.dateTo = dateTo
        self.page = page
        self.perPage = perPage
    }
}
