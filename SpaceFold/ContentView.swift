import SwiftUI

struct ContentView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    
    enum AppState: Sendable {
        case splash
        case onboarding
        case main
    }
    
    @State private var appState: AppState = .splash
    
    var body: some View {
        ZStack {
            switch appState {
            case .splash:
                SplashScreenView()
                    .transition(.opacity)
            case .onboarding:
                OnboardingView(showOnboarding: Binding(
                    get: { true },
                    set: { if !$0 { completeOnboarding() } }
                ))
                .transition(.opacity)
            case .main:
                MainTabView()
                    .transition(.opacity)
            }
        }
        .onAppear {
            startSplashTimer()
        }
        .animation(.easeInOut(duration: 0.5), value: appState)
        .preferredColorScheme(.dark)
    }
    
    private func startSplashTimer() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            if hasSeenOnboarding {
                appState = .main
            } else {
                appState = .onboarding
            }
        }
    }
    
    private func completeOnboarding() {
        hasSeenOnboarding = true
        appState = .main
    }
}

#Preview {
    ContentView()
        .environmentObject(UserData())
}
