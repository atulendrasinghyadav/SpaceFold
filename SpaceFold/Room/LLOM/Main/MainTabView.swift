import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    
    init() {
        // Customize tab bar appearance for dark theme
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.02, green: 0.02, blue: 0.05, alpha: 0.95)
        
        // Unselected items
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.white.withAlphaComponent(0.35)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.white.withAlphaComponent(0.35)
        ]
        
        // Selected items
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor.cyan
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor.cyan
        ]
        
        // TabBar
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        
        // NavigationBar Appearance
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab
            NavigationStack{
                HomeView()
            }
            .tabItem {
                Label("Explore", systemImage: "cube")
            }
            .tag(0)
            .accessibilityHint("Browse AR experiences for spacetime, time dilation, and observer frames")
            
            // About Tab
            NavigationStack{
                AboutView()
            }
            .tabItem {
                Label("About", systemImage: "sparkle")
            }
            .tag(1)
            .accessibilityHint("Learn about SpaceFold and its features")
        }
        .tint(.cyan)
    }
}

// MARK: - Simple Space Background

struct SpaceBackgroundSimple: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.02, green: 0.02, blue: 0.05),
                Color(red: 0.03, green: 0.04, blue: 0.08)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

#Preview {
    MainTabView()
}
