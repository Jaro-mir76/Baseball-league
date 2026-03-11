import Foundation

nonisolated struct TokenManager: Sendable {
    private enum Keys {
        static let accessToken = "accessToken"
        static let refreshToken = "refreshToken"
    }

    private let keychain: KeychainHelper

    init(keychain: KeychainHelper = KeychainHelper()) {
        self.keychain = keychain
    }

    func saveTokens(access: String, refresh: String) throws {
        try keychain.saveString(access, for: Keys.accessToken)
        try keychain.saveString(refresh, for: Keys.refreshToken)
    }

    func getAccessToken() -> String? {
        keychain.readString(for: Keys.accessToken)
    }

    func getRefreshToken() -> String? {
        keychain.readString(for: Keys.refreshToken)
    }

    func clearTokens() throws {
        try keychain.delete(for: Keys.accessToken)
        try keychain.delete(for: Keys.refreshToken)
    }
}
