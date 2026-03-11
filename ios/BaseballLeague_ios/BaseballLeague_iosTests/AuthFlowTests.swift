import Testing
import Foundation
@testable import BaseballLeague_ios
import BaseballShared

// MARK: - Mock URLProtocol

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - Helpers

private let testBaseURL = URL(string: "http://test.local")!

private func makeTestClient() -> APIClient {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return APIClient(
        baseURL: testBaseURL,
        tokenManager: TokenManager(keychain: KeychainHelper(service: "com.baseballleague.tests")),
        sessionConfiguration: config
    )
}

private func jsonData(_ value: some Encodable) -> Data {
    try! JSONEncoder().encode(value)
}

private func httpResponse(statusCode: Int) -> HTTPURLResponse {
    HTTPURLResponse(
        url: testBaseURL,
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: ["Content-Type": "application/json"]
    )!
}

private let mockTokenResponse = TokenResponse(
    accessToken: "test-access-token",
    refreshToken: "test-refresh-token",
    user: UserResponse(
        id: UUID(),
        email: "admin@baseball.local",
        name: "Admin",
        role: .admin,
        createdAt: nil
    )
)

// MARK: - Tests

@Suite(.serialized)
@MainActor
struct AuthFlowTests {

    @Test func loginStoresTokensAndReturnsUser() async throws {
        let client = makeTestClient()

        MockURLProtocol.requestHandler = { request in
            #expect(request.url?.path.contains("/auth/login") == true)
            #expect(request.httpMethod == "POST")
            return (httpResponse(statusCode: 200), jsonData(mockTokenResponse))
        }

        let response: TokenResponse = try await client.request(.login, body: LoginRequest(
            email: "admin@baseball.local",
            password: "password123"
        ))

        #expect(response.accessToken == "test-access-token")
        #expect(response.refreshToken == "test-refresh-token")
        #expect(response.user?.role == .admin)

        let hasTokens = await client.hasTokens
        #expect(hasTokens)
    }

    @Test func loginThenAuthenticatedRequestIncludesBearer() async throws {
        let client = makeTestClient()
        nonisolated(unsafe) var requestCount = 0

        MockURLProtocol.requestHandler = { request in
            requestCount += 1
            if requestCount == 1 {
                return (httpResponse(statusCode: 200), jsonData(mockTokenResponse))
            } else {
                let auth = request.value(forHTTPHeaderField: "Authorization")
                #expect(auth == "Bearer test-access-token")
                return (httpResponse(statusCode: 204), Data())
            }
        }

        let response: TokenResponse = try await client.request(.login, body: LoginRequest(
            email: "admin@baseball.local",
            password: "password123"
        ))
        await client.setTokens(access: response.accessToken, refresh: response.refreshToken)

        try await client.requestNoContent(.logout)
    }

    @Test func unauthorizedResponseThrowsUnauthorized() async throws {
        let client = makeTestClient()

        MockURLProtocol.requestHandler = { _ in
            let errorBody = jsonData(ErrorResponse(error: true, reason: "Invalid credentials"))
            return (httpResponse(statusCode: 401), errorBody)
        }

        do {
            let _: TokenResponse = try await client.request(.login, body: LoginRequest(
                email: "bad@test.com",
                password: "wrong"
            ))
            Issue.record("Expected unauthorized error")
        } catch let error as APIError {
            #expect(error == .unauthorized)
        }
    }

    @Test func appStateLoginUpdatesCurrentUser() async throws {
        let client = makeTestClient()

        MockURLProtocol.requestHandler = { _ in
            (httpResponse(statusCode: 200), jsonData(mockTokenResponse))
        }

        let appState = AppState(apiClient: client)
        #expect(!appState.isAuthenticated)

        try await appState.login(email: "admin@baseball.local", password: "password123")

        #expect(appState.isAuthenticated)
        #expect(appState.currentUser?.email == "admin@baseball.local")
        #expect(appState.isAdmin)
    }

    @Test func appStateLogoutClearsUser() async throws {
        let client = makeTestClient()
        nonisolated(unsafe) var requestCount = 0

        MockURLProtocol.requestHandler = { _ in
            requestCount += 1
            if requestCount == 1 {
                return (httpResponse(statusCode: 200), jsonData(mockTokenResponse))
            } else {
                return (httpResponse(statusCode: 204), Data())
            }
        }

        let appState = AppState(apiClient: client)
        try await appState.login(email: "admin@baseball.local", password: "password123")
        #expect(appState.isAuthenticated)

        await appState.logout()
        #expect(!appState.isAuthenticated)
        #expect(appState.currentUser == nil)
    }

    @Test func tokenRefreshOn401ThenRetry() async throws {
        let client = makeTestClient()
        await client.setTokens(access: "expired-token", refresh: "valid-refresh")
        nonisolated(unsafe) var requestCount = 0

        let refreshResponse = TokenResponse(
            accessToken: "new-access-token",
            refreshToken: "new-refresh-token",
            user: nil
        )

        MockURLProtocol.requestHandler = { request in
            requestCount += 1
            if requestCount == 1 {
                return (httpResponse(statusCode: 401), jsonData(ErrorResponse(error: true, reason: "Expired")))
            } else if requestCount == 2 {
                #expect(request.url?.path.contains("/auth/refresh") == true)
                return (httpResponse(statusCode: 200), jsonData(refreshResponse))
            } else {
                let auth = request.value(forHTTPHeaderField: "Authorization")
                #expect(auth == "Bearer new-access-token")
                return (httpResponse(statusCode: 204), Data())
            }
        }

        try await client.requestNoContent(.logout)
        #expect(requestCount == 3)
    }
}

// MARK: - APIError Equatable

extension APIError: @retroactive Equatable {
    public static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case (.unauthorized, .unauthorized),
             (.forbidden, .forbidden),
             (.notFound, .notFound),
             (.serverError, .serverError):
            true
        case (.conflict(let a), .conflict(let b)),
             (.validationFailed(let a), .validationFailed(let b)):
            a == b
        default:
            false
        }
    }
}
