import SwiftUI

// MARK: - View Extensions

extension View {
    /// Apply consistent padding and styling
    func screenPadding() -> some View {
        self.padding(.horizontal, AppTheme.Spacing.large)
    }
    
    /// Fade in animation
    func fadeIn(delay: Double = 0) -> some View {
        self.modifier(FadeInModifier(delay: delay))
    }
}

struct FadeInModifier: ViewModifier {
    let delay: Double
    @State private var opacity: Double = 0
    
    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeIn(duration: 0.5).delay(delay)) {
                    opacity = 1
                }
            }
    }
}

// MARK: - Color Extensions

extension Color {
    static let spaceBlack = Color(red: 0.05, green: 0.05, blue: 0.1)
    static let cosmicPurple = Color(red: 0.4, green: 0.2, blue: 0.6)
    static let nebulaBlue = Color(red: 0.2, green: 0.4, blue: 0.8)
}

// MARK: - Animation Extensions

extension Animation {
    static let smoothSpring = Animation.spring(response: 0.4, dampingFraction: 0.8)
    static let quickBounce = Animation.spring(response: 0.3, dampingFraction: 0.6)
}

// MARK: - Double Extensions

extension Double {
    /// Format as percentage of light speed
    var asLightSpeed: String {
        return String(format: "%.1f%% c", self * 100)
    }
    
    /// Lorentz factor calculation
    var lorentzFactor: Double {
        guard self < 1 else { return .infinity }
        return 1 / sqrt(1 - self * self)
    }
}
