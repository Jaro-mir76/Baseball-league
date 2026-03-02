public enum GameStatus: String, Codable, Sendable, Equatable {
    case scheduled
    case live
    case `final`
}
