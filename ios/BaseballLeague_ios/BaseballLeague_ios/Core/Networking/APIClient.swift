import Foundation
import BaseballShared

actor APIClient {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let tokenManager: TokenManager

    private var accessToken: String?
    private var refreshToken: String?

    private var isRefreshing = false
    private var refreshContinuations: [CheckedContinuation<TokenResponse, any Error>] = []

    init(baseURL: URL = URL(string: "http://localhost:8080")!, tokenManager: TokenManager = TokenManager()) {
        self.baseURL = baseURL
        self.tokenManager = tokenManager
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()

        // Restore tokens from Keychain
        self.accessToken = tokenManager.getAccessToken()
        self.refreshToken = tokenManager.getRefreshToken()
    }

    var hasTokens: Bool {
        refreshToken != nil
    }

    var currentRefreshTokenValue: String? {
        refreshToken
    }

    // MARK: - Token Management

    func setTokens(access: String, refresh: String) {
        self.accessToken = access
        self.refreshToken = refresh
        try? tokenManager.saveTokens(access: access, refresh: refresh)
    }

    func clearTokens() {
        self.accessToken = nil
        self.refreshToken = nil
        try? tokenManager.clearTokens()
    }

    // MARK: - Public Request Methods

    func request<T: Decodable>(
        _ endpoint: Endpoint,
        body: (some Encodable)? = Optional<Never>.none
    ) async throws -> T {
        try await performRequest(endpoint, body: body)
    }

    func requestNoContent(
        _ endpoint: Endpoint,
        body: (some Encodable)? = Optional<Never>.none
    ) async throws {
        let _: EmptyResponse = try await performRequest(endpoint, body: body)
    }

    // MARK: - Private

    private func performRequest<T: Decodable>(
        _ endpoint: Endpoint,
        body: (some Encodable)?,
        isRetry: Bool = false
    ) async throws -> T {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent(endpoint.path))
        urlRequest.httpMethod = endpoint.method
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if endpoint.requiresAuth, let token = accessToken {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            urlRequest.httpBody = try encoder.encode(body)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        let statusCode = httpResponse.statusCode

        guard (200...299).contains(statusCode) else {
            if statusCode == 401, endpoint.requiresAuth, !isRetry {
                try await refreshTokens()
                return try await performRequest(endpoint, body: body, isRetry: true)
            }
            throw APIError.fromHTTPStatus(statusCode, data: data)
        }

        if statusCode == 204 || data.isEmpty {
            guard let empty = EmptyResponse() as? T else {
                throw APIError.decodingError(
                    DecodingError.dataCorrupted(
                        .init(codingPath: [], debugDescription: "Expected content but got empty response")
                    )
                )
            }
            return empty
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            #if DEBUG
            print("[APIClient] Decoding \(T.self) failed: \(error)")
            if let raw = String(data: data, encoding: .utf8) {
                print("[APIClient] Raw response: \(raw)")
            }
            #endif
            throw APIError.decodingError(error)
        }
    }

    private func refreshTokens() async throws {
        if isRefreshing {
            _ = try await withCheckedThrowingContinuation { continuation in
                refreshContinuations.append(continuation)
            }
            return
        }

        isRefreshing = true

        do {
            guard let currentRefreshToken = refreshToken else {
                throw APIError.unauthorized
            }

            let body = RefreshRequest(refreshToken: currentRefreshToken)
            let tokenResponse: TokenResponse = try await performRequest(
                .refresh,
                body: body,
                isRetry: true
            )

            self.accessToken = tokenResponse.accessToken
            self.refreshToken = tokenResponse.refreshToken
            try? tokenManager.saveTokens(access: tokenResponse.accessToken, refresh: tokenResponse.refreshToken)

            isRefreshing = false
            let continuations = refreshContinuations
            refreshContinuations.removeAll()
            for continuation in continuations {
                continuation.resume(returning: tokenResponse)
            }
        } catch {
            isRefreshing = false
            let continuations = refreshContinuations
            refreshContinuations.removeAll()
            for continuation in continuations {
                continuation.resume(throwing: error)
            }

            self.accessToken = nil
            self.refreshToken = nil
            try? tokenManager.clearTokens()
            throw APIError.unauthorized
        }
    }
}

nonisolated private struct EmptyResponse: Decodable, Sendable {}
