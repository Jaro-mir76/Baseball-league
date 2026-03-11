@testable import App
import VaporTesting
import Testing

struct AppTests {
    @Test func healthEndpoint() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "health") { res async in
                #expect(res.status == .ok)
            }
        }
    }
}
