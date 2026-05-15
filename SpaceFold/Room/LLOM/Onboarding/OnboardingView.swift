import SwiftUI

struct OnboardingView: View {
    @Binding var showOnboarding: Bool
    @State private var currentPage = 0
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Deep space gradient background
                DeepSpaceBackground()
                
                // Parallax star field
                ParallaxStarField()
                
                // Main content
                VStack(spacing: 0) {
                    Spacer()
                    
                    // Logo and App Name
                    LogoSection()
                    
                    Spacer()
                    
                    // Feature Cards
                    FeatureCardsCarousel(
                        currentPage: $currentPage,
                        dragOffset: $dragOffset,
                        geometry: geometry
                    )
                    
                    Spacer()
                    
                    // Pagination dots
                    PaginationDots(currentPage: currentPage)
                    
                    Spacer()
                    
                    // Get Started Button
                    GetStartedButton {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            showOnboarding = false
                        }
                    }
                    
                    Spacer()
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Deep Space Background

struct DeepSpaceBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.02, green: 0.02, blue: 0.06),
                Color(red: 0.04, green: 0.05, blue: 0.12),
                Color(red: 0.03, green: 0.04, blue: 0.10)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - Parallax Star Field

struct ParallaxStarField: View {
    var body: some View {
        ZStack {
            // Far layer (slowest)
            StarLayer(starCount: 40, speed: 0.3, size: 1...1.5, opacity: 0.3)
            
            // Middle layer
            StarLayer(starCount: 30, speed: 0.5, size: 1.5...2, opacity: 0.5)
            
            // Near layer (fastest)
            StarLayer(starCount: 20, speed: 0.8, size: 2...3, opacity: 0.7)
        }
    }
}

struct StarLayer: View {
    let starCount: Int
    let speed: Double
    let size: ClosedRange<CGFloat>
    let opacity: Double
    
    @State private var offset: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<starCount, id: \.self) { index in
                    let seed = Double(index * 1234567)
                    let x = seededRandom(seed: seed) * geometry.size.width
                    let baseY = seededRandom(seed: seed + 1) * geometry.size.height * 2
                    let starSize = CGFloat(seededRandom(seed: seed + 2)) * (size.upperBound - size.lowerBound) + size.lowerBound
                    
                    Circle()
                        .fill(.white.opacity(opacity))
                        .frame(width: starSize, height: starSize)
                        .position(
                            x: x + sin(baseY * 0.01) * 20,
                            y: (baseY + offset).truncatingRemainder(dividingBy: geometry.size.height * 1.5) - geometry.size.height * 0.25
                        )
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 60 / speed).repeatForever(autoreverses: false)) {
                offset = 500
            }
        }
    }
    
    private func seededRandom(seed: Double) -> Double {
        let x = sin(seed) * 10000
        return x - floor(x)
    }
}

// MARK: - Logo Section

struct LogoSection: View {
    @State private var appeared = false
    
    var body: some View {
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
                .font(.system(size: 32, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.95))
                .tracking(2)
            
            // Subtitle
            Text("See Space. Fold Time.")
                .font(.system(size: 14, weight: .regular, design: .default))
                .foregroundColor(.white.opacity(0.5))
                .tracking(1)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                appeared = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("SpaceFold. See Space. Fold Time.")
    }
}

// MARK: - Feature Cards Carousel

struct FeatureCardsCarousel: View {
    @Binding var currentPage: Int
    @Binding var dragOffset: CGFloat
    let geometry: GeometryProxy
    
    private let cards: [OnboardingCard] = [
        OnboardingCard(
            icon: "circle.grid.3x3",
            title: "Touch Spacetime",
            description: "See gravity not as a force, but as the bending of space and time.",
            iconAnimation: .grid
        ),
        OnboardingCard(
            icon: "clock",
            title: "Experience Time Dilation",
            description: "Move through space and watch time change with motion.",
            iconAnimation: .clock
        ),
        OnboardingCard(
            icon: "person.2",
            title: "Change the Observer",
            description: "Discover how motion reshapes what \"now\" means.",
            iconAnimation: .observers
        )
    ]
    
    // MARK: - Layout Constants
    private struct LayoutConfig {
        static let cardWidth: CGFloat = 340
        static let spacing: CGFloat = 20
        static let cardHeight: CGFloat = 450
        static let peekAmount: CGFloat = 20 // Amount of next card visible
    }
    
    var body: some View {
        // Calculate dynamic width for smaller screens, but max out at LayoutConfig.cardWidth
        let availableWidth = geometry.size.width
        let cardWidth = min(availableWidth - (LayoutConfig.peekAmount * 2 + LayoutConfig.spacing * 2), LayoutConfig.cardWidth)
        let spacing = LayoutConfig.spacing
        
        ZStack {
            ForEach(Array(cards.enumerated()), id: \.offset) { index, card in
                let offset = cardOffset(for: index, cardWidth: cardWidth, spacing: spacing)
                
                // Calculate rotation based on offset from center
                let normalizedOffset = offset / availableWidth
                let rotationAngle = Double(-normalizedOffset * 10) // Reduced tilt for stability
                
                FeatureCardView(card: card, isActive: index == currentPage)
                    .frame(width: cardWidth, height: LayoutConfig.cardHeight)
                    .offset(x: offset)
                    .scaleEffect(index == currentPage ? 1.0 : 0.95) // Subtle scale
                    .opacity(index == currentPage ? 1.0 : 0.5)
                    .rotation3DEffect(
                        .degrees(rotationAngle),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.5
                    )
                    .zIndex(index == currentPage ? 10 : Double(cards.count - index))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentPage)
                    .animation(.interactiveSpring(), value: dragOffset)
            }
        }
        .frame(height: 200)
        .onChange(of: currentPage) {
            let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation.width
                }
                .onEnded { value in
                    let threshold: CGFloat = cardWidth / 3
                    var newPage = currentPage
                    
                    if value.translation.width < -threshold {
                        newPage = min(currentPage + 1, cards.count - 1)
                    } else if value.translation.width > threshold {
                        newPage = max(currentPage - 1, 0)
                    }
                    
                    if newPage != currentPage {
                        currentPage = newPage
                    }
                    
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        dragOffset = 0
                    }
                }
        )
    }
    
    private func cardOffset(for index: Int, cardWidth: CGFloat, spacing: CGFloat) -> CGFloat {
        let totalItemWidth = cardWidth + spacing
        let baseOffset = CGFloat(index - currentPage) * totalItemWidth
        return baseOffset + dragOffset // 1:1 drag mapping
    }
}

struct OnboardingCard: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let iconAnimation: CardIconAnimation
    
    enum CardIconAnimation {
        case grid, clock, observers
    }
}

struct FeatureCardView: View {
    let card: OnboardingCard
    let isActive: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // Animated icon
            CardIconView(animation: card.iconAnimation, isActive: isActive)
                .frame(height: 70)
            
            // Title
            Text(card.title)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            // Description
            Text(card.description)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 8)
        }
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial.opacity(0.5))
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white.opacity(0.05))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.2), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(card.title). \(card.description)")
    }
}

// MARK: - Card Icon Animations

struct CardIconView: View {
    let animation: OnboardingCard.CardIconAnimation
    let isActive: Bool
    
    @State private var animating = false
    
    var body: some View {
        Group {
            switch animation {
            case .grid:
                GridIconView(animating: animating && isActive)
            case .clock:
                ClockIconView(animating: animating && isActive)
            case .observers:
                ObserversIconView(animating: animating && isActive)
            }
        }
        .onChange(of: isActive) { oldValue, newValue in
            if newValue {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    animating = true
                }
            } else {
                animating = false
            }
        }
        .onAppear {
            if isActive {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    animating = true
                }
            }
        }
    }
}

struct GridIconView: View {
    let animating: Bool
    
    var body: some View {
        ZStack {
            // Curved grid representation
            ForEach(0..<5, id: \.self) { row in
                ForEach(0..<5, id: \.self) { col in
                    let x = CGFloat(col - 2) * 12
                    let y = CGFloat(row - 2) * 12
                    let distFromCenter = sqrt(x*x + y*y)
                    let deformation = animating ? min(distFromCenter * 0.15, 8) : 0
                    
                    Circle()
                        .fill(.cyan.opacity(0.8))
                        .frame(width: 4, height: 4)
                        .offset(x: x, y: y + deformation)
                }
            }
        }
        .animation(.easeInOut(duration: 2), value: animating)
    }
}

struct ClockIconView: View {
    let animating: Bool
    
    var body: some View {
        HStack(spacing: 20) {
            // Normal clock
            ClockFace(speed: 1.0, color: .white.opacity(0.6))
                .frame(width: 40, height: 40)
            
            // Dilated clock (slower)
            ClockFace(speed: animating ? 0.3 : 1.0, color: .cyan)
                .frame(width: 40, height: 40)
                .scaleEffect(x: animating ? 1.1 : 1.0, y: 1.0)
        }
    }
}

struct ClockFace: View {
    let speed: Double
    let color: Color
    
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.3), lineWidth: 2)
            
            Rectangle()
                .fill(color)
                .frame(width: 2, height: 14)
                .offset(y: -7)
                .rotationEffect(.degrees(rotation))
        }
        .onAppear {
            withAnimation(.linear(duration: 4 / speed).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

struct ObserversIconView: View {
    let animating: Bool
    
    var body: some View {
        HStack(spacing: 30) {
            // Observer A
            VStack(spacing: 4) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.7))
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(.cyan)
                    .frame(width: 20, height: 3)
                    .offset(y: animating ? 0 : 5)
            }
            
            // Observer B
            VStack(spacing: 4) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.cyan)
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(.white.opacity(0.7))
                    .frame(width: 20, height: 3)
                    .offset(y: animating ? 5 : 0)
            }
        }
        .animation(.easeInOut(duration: 1.5), value: animating)
    }
}

// MARK: - Pagination Dots

struct PaginationDots: View {
    let currentPage: Int
    private let totalPages = 3
    
    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<totalPages, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? Color.cyan : Color.white.opacity(0.3))
                    .frame(width: index == currentPage ? 10 : 8, height: index == currentPage ? 10 : 8)
                    .animation(.spring(response: 0.3), value: currentPage)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(currentPage + 1) of \(totalPages)")
    }
}

// MARK: - Get Started Button

struct GetStartedButton: View {
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            action()
        }) {
            Text("Get Started")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 200, height: 54)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.2, green: 0.5, blue: 0.8),
                                    Color(red: 0.1, green: 0.4, blue: 0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: Color(red: 0.1, green: 0.4, blue: 0.7).opacity(0.5), radius: 15, y: 5)
                .scaleEffect(isPressed ? 0.96 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityHint("Begins the SpaceFold experience")
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
        )
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(showOnboarding: .constant(true))
}
