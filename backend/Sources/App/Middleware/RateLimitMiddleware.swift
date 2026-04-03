import Vapor

actor RateLimitStore {
    private var entries: [String: [Date]] = [:]
    private let maxRequests: Int
    private let window: TimeInterval

    init(maxRequests: Int, window: TimeInterval) {
        self.maxRequests = maxRequests
        self.window = window
    }

    func shouldAllow(key: String) -> Bool {
        let now = Date()
        let cutoff = now.addingTimeInterval(-window)

        var timestamps = entries[key, default: []]
        timestamps.removeAll { $0 < cutoff }

        if timestamps.count >= maxRequests {
            entries[key] = timestamps
            return false
        }

        timestamps.append(now)
        entries[key] = timestamps
        return true
    }
}

struct RateLimitMiddleware: AsyncMiddleware {
    let store: RateLimitStore

    init(maxRequests: Int, windowSeconds: TimeInterval) {
        self.store = RateLimitStore(maxRequests: maxRequests, window: windowSeconds)
    }

    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        let key = request.peerAddress?.description ?? request.remoteAddress?.description ?? "unknown"

        guard await store.shouldAllow(key: key) else {
            throw Abort(.tooManyRequests, reason: "Rate limit exceeded. Try again later.")
        }

        return try await next.respond(to: request)
    }
}
