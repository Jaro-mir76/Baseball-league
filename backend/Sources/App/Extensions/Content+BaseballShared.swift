import Vapor
import BaseballShared

// MARK: - Auth
extension LoginRequest: @retroactive Content {}
extension RegisterRequest: @retroactive Content {}
extension RefreshRequest: @retroactive Content {}
extension TokenResponse: @retroactive Content {}
extension UserResponse: @retroactive Content {}

// MARK: - Teams
extension TeamRequest: @retroactive Content {}
extension TeamResponse: @retroactive Content {}
extension TeamDetailResponse: @retroactive Content {}

// MARK: - Players
extension PlayerRequest: @retroactive Content {}
extension PlayerResponse: @retroactive Content {}
extension PlayerSummary: @retroactive Content {}
extension PlayerUpdateRequest: @retroactive Content {}

// MARK: - Games
extension GameRequest: @retroactive Content {}
extension GameResponse: @retroactive Content {}
extension GameFilterRequest: @retroactive Content {}
extension GameStatusUpdateRequest: @retroactive Content {}

// MARK: - Game Events
extension GameEventRequest: @retroactive Content {}
extension GameEventResponse: @retroactive Content {}

// MARK: - Common
extension ErrorResponse: @retroactive Content {}
extension PageMetadata: @retroactive Content {}
extension PaginatedResponse: @retroactive Content {}
extension TeamSummary: @retroactive Content {}
extension UserSummary: @retroactive Content {}
