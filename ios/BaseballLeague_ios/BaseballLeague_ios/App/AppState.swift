import Foundation
import Observation
import BaseballShared

@Observable
final class AppState {
    var currentUser: UserResponse?
    var isAuthenticated: Bool { currentUser != nil }

    let apiClient: APIClient

    var isAdmin: Bool {
        currentUser?.role == .admin
    }

    var isScorer: Bool {
        currentUser?.role == .scorer
    }

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func login(email: String, password: String) async throws {
        let body = LoginRequest(email: email, password: password)
        let response: TokenResponse = try await apiClient.request(.login, body: body)
        await apiClient.setTokens(access: response.accessToken, refresh: response.refreshToken)
        currentUser = response.user
    }

    func register(email: String, password: String, name: String) async throws {
        let body = RegisterRequest(email: email, password: password, name: name, role: .viewer)
        let response: TokenResponse = try await apiClient.request(.signup, body: body)
        await apiClient.setTokens(access: response.accessToken, refresh: response.refreshToken)
        currentUser = response.user
    }

    func logout() async {
        try? await apiClient.requestNoContent(.logout)
        await apiClient.clearTokens()
        currentUser = nil
    }

    func restoreSession() async {
        guard let storedRefreshToken = await apiClient.currentRefreshTokenValue else { return }
        do {
            let body = RefreshRequest(refreshToken: storedRefreshToken)
            let response: TokenResponse = try await apiClient.request(.refresh, body: body)
            await apiClient.setTokens(access: response.accessToken, refresh: response.refreshToken)
            currentUser = response.user
        } catch {
            await apiClient.clearTokens()
        }
    }
}
