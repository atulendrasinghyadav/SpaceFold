import SwiftUI

struct SplashScreenView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Deep space gradient background
            DeepSpaceBackground()
            
            // Parallax star field
            ParallaxStarField()
            
            // Logo and App Name
            VStack(spacing: 12) {
                // Logo icon
                ZStack {
                    // Subtle glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.cyan.opacity(0.15),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 60
                            )
                        )
                        .frame(width: 120, height: 120)
                    
                    // Logo
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
    //                    .foregroundStyle(
    //                        LinearGradient(
    //                            colors: [.white.opacity(0.9), .cyan.opacity(0.7)],
    //                            startPoint: .topLeading,
    //                            endPoint: .bottomTrailing
    //                        )
    //                    )
    //                    .opacity(0.2)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .cyan.opacity(0.2), radius: 40)
                }
                
                // App name
                Text("SpaceFold")
                    .font(.system(size: 42, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.95))
                    .tracking(2)
                    .scaleEffect(isAnimating ? 1.0 : 0.9)
                    .opacity(isAnimating ? 1.0 : 0.0)
                
                // Subtitle
                Text("See Space. Fold Time.")
                    .font(.system(size: 16, weight: .regular, design: .default))
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(1)
                    .offset(y: isAnimating ? 0 : 10)
                    .opacity(isAnimating ? 1.0 : 0.0)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("SpaceFold. See Space. Fold Time.")
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) {
                isAnimating = true
            }
        }
    }
}

#Preview {
    SplashScreenView()
}
