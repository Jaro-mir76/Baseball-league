import SwiftUI
import BaseballShared

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if appState.isAuthenticated {
                MainTabView()
            } else {
                LoginView(appState: appState)
            }
        }
        .task {
            await appState.restoreSession()
        }
    }
}

struct MainTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            Tab("Games", systemImage: "sportscourt") {
                NavigationStack {
                    Text("Games")
                        .navigationTitle("Games")
                }
            }

            Tab("Teams", systemImage: "person.3") {
                NavigationStack {
                    TeamListView(apiClient: appState.apiClient)
                        .navigationDestination(for: UUID.self) { teamId in
                            TeamDetailView(apiClient: appState.apiClient, teamId: teamId)
                        }
                }
            }

            Tab("Profile", systemImage: "person.circle") {
                NavigationStack {
                    VStack(spacing: 16) {
                        if let user = appState.currentUser {
                            Text(user.name)
                                .font(.title2)
                            Text(user.email)
                                .foregroundStyle(.secondary)
                            Text(user.role.rawValue.capitalized)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(.fill)
                                .clipShape(Capsule())
                        }

                        Button("Log Out", role: .destructive) {
                            Task {
                                await appState.logout()
                            }
                        }
                    }
                    .navigationTitle("Profile")
                }
            }
        }
    }
}
