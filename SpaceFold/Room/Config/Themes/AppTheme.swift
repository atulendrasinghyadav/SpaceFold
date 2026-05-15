import SwiftUI

/// App-wide color palette and typography
struct AppTheme {
    
    // MARK: - Colors
    
    struct Colors {
        // Primary gradients
        static let spacetimeGradient = [Color.purple, Color.blue]
        static let timeWalkGradient = [Color.cyan, Color.indigo]
        static let observerGradient = [Color.orange, Color.pink]
        
        // Background
        static let background = Color(red: 0.05, green: 0.05, blue: 0.12)
        static let cardBackground = Color.white.opacity(0.08)
        
        // Accent
        static let primary = Color.cyan
        static let secondary = Color.purple
        
        // Text
        static let textPrimary = Color.white
        static let textSecondary = Color.white.opacity(0.7)
        
        // Chat
        static let userBubble = Color.cyan.opacity(0.2)
        static let aiBubble = Color.purple.opacity(0.12)
        static let inputBackground = Color.white.opacity(0.04)
    }
    
    // MARK: - Gradients
    
    struct Gradients {
        static let cosmic = LinearGradient(
            colors: [
                Color(red: 0.1, green: 0.05, blue: 0.2),
                Color(red: 0.02, green: 0.02, blue: 0.08)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        
        static let glow = RadialGradient(
            colors: [.purple.opacity(0.3), .clear],
            center: .center,
            startRadius: 0,
            endRadius: 200
        )
    }
    
    // MARK: - Typography
    
    struct Typography {
        static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
        static let title = Font.system(size: 24, weight: .bold, design: .rounded)
        static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 15, weight: .regular, design: .default)
        static let caption = Font.system(size: 12, weight: .medium, design: .default)
        static let monospace = Font.system(size: 14, weight: .medium, design: .monospaced)
    }
    
    // MARK: - Spacing
    
    struct Spacing {
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let extraLarge: CGFloat = 32
    }
    
    // MARK: - Corner Radius
    
    struct CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let extraLarge: CGFloat = 32
    }
}

// MARK: - View Extensions

extension View {
    func cosmicBackground() -> some View {
        self.background(AppTheme.Gradients.cosmic)
    }
    
    /// Applies the native iOS 26 Liquid Glass effect with rounded corners
    func glassCard() -> some View {
        self.glassEffect(.regular, in: .rect(cornerRadius: AppTheme.CornerRadius.large))
    }
}
