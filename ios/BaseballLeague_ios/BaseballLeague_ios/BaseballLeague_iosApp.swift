import SwiftUI

@main
struct BaseballLeague_iosApp: App {
    @State private var appState: AppState

    init() {
        let apiClient = APIClient()
        _appState = State(initialValue: AppState(apiClient: apiClient))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
    }
}
