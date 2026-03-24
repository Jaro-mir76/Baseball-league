import SwiftUI
import BaseballShared

struct RequireRole: ViewModifier {
    @Environment(AppState.self) private var appState
    let roles: Set<UserRole>

    func body(content: Content) -> some View {
        if let role = appState.currentUser?.role, roles.contains(role) {
            content
        }
    }
}

extension View {
    func visible(to roles: UserRole...) -> some View {
        modifier(RequireRole(roles: Set(roles)))
    }

    func adminOnly() -> some View {
        modifier(RequireRole(roles: [.admin]))
    }
}
