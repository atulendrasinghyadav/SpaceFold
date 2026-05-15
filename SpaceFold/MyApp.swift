import SwiftUI

@main
struct SpaceFoldApp: App {
    @StateObject private var userData = UserData()
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(userData)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                break
            case .inactive, .background:
                // Allow AR sessions to pause gracefully when app is backgrounded.
                // Individual AR coordinators handle their own cleanup via onDisappear,
                // but this ensures we're not burning CPU/GPU in the background.
                break
            @unknown default:
                break
            }
        }
    }
}
