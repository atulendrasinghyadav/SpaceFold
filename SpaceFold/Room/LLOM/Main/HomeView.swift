import SwiftUI
import CoreMotion
import Combine

struct HomeView: View {
    @StateObject private var motionManager = DeviceMotionManager()
    @EnvironmentObject var userData: UserData
    
    var body: some View {
        ZStack {
            // Deep space background
            AnimatedSpaceBackground()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    
                    // Primary Feature Cards (Vertical Stack)
                    FeatureCardsStack(tilt: motionManager.tilt)
                        .padding(.top, 20)
                        
                    // Exploration Progress Cards
                    ExplorationProgress()
                        .padding(.top, 40)
                        
                    // Bottom spacing
                    Spacer(minLength: 20)
                }
            }
        }
        .navigationTitle("Explore Spacetime")
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            motionManager.startMonitoring()
        }
        .onDisappear {
            motionManager.stopMonitoring()
        }
    }
}

// MARK: - Device Motion Manager

@MainActor
class DeviceMotionManager: ObservableObject {
    @Published var tilt: CGSize = .zero
    private lazy var motionManager: CMMotionManager = CMMotionManager()
    
    func startMonitoring() {
        guard motionManager.isDeviceMotionAvailable else { return }
        
        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion = motion else { return }
            Task { @MainActor in
                self?.tilt = CGSize(
                    width: motion.attitude.roll * 8,
                    height: motion.attitude.pitch * 8
                )
            }
        }
    }
    
    func stopMonitoring() {
        motionManager.stopDeviceMotionUpdates()
    }
}

// MARK: - Animated Space Background

struct AnimatedSpaceBackground: View {
    var body: some View {
        ZStack {
            // Deep base
            Color(red: 0.01, green: 0.01, blue: 0.05).ignoresSafeArea()
            
            // Stars
            DriftingStars()
            
            // Shooting stars
            ShootingStarLayer()
        }
    }
}

struct DriftingStars: View {
    var body: some View {
        ZStack {
            // Far stars (slow)
            DriftingStarLayer(count: 60, speed: 0.6, size: 1...1.5, opacity: 0.4)
            
            // Near stars (faster)
            DriftingStarLayer(count: 30, speed: 0.9, size: 1.5...2.5, opacity: 0.7)
        }
    }
}

struct DriftingStarLayer: View {
    let count: Int
    let speed: Double
    let size: ClosedRange<CGFloat>
    let opacity: Double
    
    @State private var offset: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<count, id: \.self) { i in
                    let seed = Double(i * 98765)
                    let x = seededRandom(seed: seed) * geometry.size.width
                    let y = seededRandom(seed: seed + 1) * geometry.size.height
                    let s = seededRandom(seed: seed + 2) * (size.upperBound - size.lowerBound) + size.lowerBound
                    
                    Circle()
                        .fill(.white.opacity(opacity * seededRandom(seed: seed + 3)))
                        .frame(width: s, height: s)
                        .position(x: x, y: (y + offset).truncatingRemainder(dividingBy: geometry.size.height))
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.linear(duration: 30 / speed).repeatForever(autoreverses: false)) {
                offset = 1000
            }
        }
    }
    
    private func seededRandom(seed: Double) -> Double {
        let x = sin(seed) * 10000
        return x - floor(x)
    }
}

struct ShootingStarLayer: View {
    @State private var offset: CGFloat = -500
    @State private var isActive = false
    
    // Timer to trigger shooting stars randomly
    let timer = Timer.publish(every: 8, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if isActive {
                    ShootingStar()
                        .offset(x: offset, y: offset * 0.6)
                        .position(x: geometry.size.width + 100, y: -100)
                }
            }
            .onReceive(timer) { _ in
                triggerShootingStar(in: geometry)
            }
        }
        .ignoresSafeArea()
    }
    
    private func triggerShootingStar(in geometry: GeometryProxy) {
        isActive = true
        offset = -500
        
        withAnimation(.easeOut(duration: 1.5)) {
            offset = geometry.size.width + 500
        }
        
        // Reset after animation
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1600))
            isActive = false
            offset = -500
        }
    }
}

struct ShootingStar: View {
    var body: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(.white)
                .frame(width: 4, height: 4)
                .shadow(color: .white, radius: 4, x: 0, y: 0)
            
            LinearGradient(
                colors: [.white.opacity(0.8), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 100, height: 2)
            .mask(Capsule())
        }
        .rotationEffect(.degrees(135))
    }
}



// MARK: - Feature Cards Stack

struct FeatureCardsStack: View {
    let tilt: CGSize
    @EnvironmentObject var userData: UserData
    
    var body: some View {
        GlassEffectContainer {
            VStack(spacing: 20) {
                // Card 1: Spacetime Fabric
                NavigationLink(destination: SpacetimeFabricView()) {
                    SpacetimeFabricCardContent(tilt: tilt)
                }
                .simultaneousGesture(TapGesture().onEnded {
                    userData.markFeatureVisited("spacetime_fabric")
                })
                .accessibilityLabel("Spacetime Fabric: Gravity as geometry")
                .accessibilityHint("Opens the Spacetime Fabric AR experience")
                
                // Card 2: Time Walk
                NavigationLink(destination: TimeWalkView()) {
                    TimeWalkCardContent(tilt: tilt)
                }
                .simultaneousGesture(TapGesture().onEnded {
                    userData.markFeatureVisited("time_walk")
                })
                .accessibilityLabel("Time Walk: Motion changes time")
                .accessibilityHint("Opens the Time Dilation AR experience")
                
                // Card 3: Observer Frames
                NavigationLink(destination: ObserverSwitchView()) {
                    ObserverFramesCardContent(tilt: tilt)
                }
                .simultaneousGesture(TapGesture().onEnded {
                    userData.markFeatureVisited("observer_frames")
                })
                .accessibilityLabel("Observer Frames: No absolute time")
                .accessibilityHint("Opens the Observer Frames AR experience")
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Spacetime Fabric Card

struct SpacetimeFabricCardContent: View {
    let tilt: CGSize
    
    @State private var breathScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Subtle glow at center
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.cyan.opacity(0.15), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 100
                    )
                )
                .scaleEffect(breathScale)
                .offset(x: 40, y: 20)
            
            // Grid visualization
            GridVisualization()
                .offset(x: 60, y: 10)
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                Text("Spacetime Fabric")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Gravity as geometry")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.5))
                
                Spacer()
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 160)
        .glassEffect(.clear.interactive(), in: .rect(cornerRadius: 24))
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                breathScale = 1.15
            }
        }
    }
}

struct GridVisualization: View {
    @State private var deform: CGFloat = 0
    
    var body: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { row in
                ForEach(0..<7, id: \.self) { col in
                    let x = CGFloat(col - 3) * 14
                    let y = CGFloat(row - 2) * 14
                    let dist = sqrt(x*x + y*y)
                    let offset = deform * max(0, 20 - dist) * 0.3
                    
                    Circle()
                        .fill(.cyan.opacity(0.4))
                        .frame(width: 3, height: 3)
                        .offset(x: x, y: y + offset)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                deform = 1
            }
        }
    }
}

// MARK: - Time Walk Card

struct TimeWalkCardContent: View {
    let tilt: CGSize
    
    var body: some View {
        ZStack {
            // Two clocks visualization
            HStack(spacing: 20) {
                Spacer()
                DualClocksVisualization()
                    .padding(.trailing, 24)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Time Walk")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Motion changes time")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.5))
                
                Spacer()
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 160)
        .glassEffect(.clear.interactive(), in: .rect(cornerRadius: 24))
    }
}

struct DualClocksVisualization: View {
    @State private var rotation1: Double = 0
    @State private var rotation2: Double = 0
    @State private var stretch: CGFloat = 1.0
    
    var body: some View {
        HStack(spacing: 16) {
            // Normal clock
            ClockIcon(rotation: rotation1, color: .white.opacity(0.3))
                .frame(width: 40, height: 40)
            
            // Dilated clock (slower, stretched)
            ClockIcon(rotation: rotation2, color: .cyan.opacity(0.6))
                .frame(width: 40, height: 40)
                .scaleEffect(x: stretch, y: 1.0)
        }
        .onAppear {
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                rotation1 = 360
            }
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                rotation2 = 360
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                stretch = 1.1
            }
        }
    }
}

struct ClockIcon: View {
    let rotation: Double
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color, lineWidth: 2)
            
            Rectangle()
                .fill(color)
                .frame(width: 1.5, height: 14)
                .offset(y: -7)
                .rotationEffect(.degrees(rotation))
        }
    }
}

// MARK: - Observer Frames Card

struct ObserverFramesCardContent: View {
    let tilt: CGSize
    
    @State private var pulseOpacity: Double = 0.3
    
    var body: some View {
        ZStack {
            // Split perspective visualization
            HStack(spacing: 0) {
                Spacer()
                SplitPerspectiveVisualization(pulseOpacity: pulseOpacity)
                    .padding(.trailing, 24)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Observer Frames")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("No absolute time")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.5))
                
                Spacer()
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 160)
        .glassEffect(.clear.interactive(), in: .rect(cornerRadius: 24))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseOpacity = 0.7
            }
        }
    }
}

struct SplitPerspectiveVisualization: View {
    let pulseOpacity: Double
    
    var body: some View {
        HStack(spacing: 20) {
            // Observer A
            VStack(spacing: 4) {
                Image(systemName: "eye")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(.white.opacity(0.4))
                
                RoundedRectangle(cornerRadius: 1)
                    .fill(.white.opacity(0.3))
                    .frame(width: 16, height: 2)
            }
            
            // Pulse between
            Circle()
                .fill(.cyan.opacity(pulseOpacity))
                .frame(width: 6, height: 6)
            
            // Observer B
            VStack(spacing: 4) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(.cyan.opacity(0.7))
                
                RoundedRectangle(cornerRadius: 1)
                    .fill(.cyan.opacity(0.5))
                    .frame(width: 16, height: 2)
            }
        }
    }
}

// MARK: - Exploration Progress

struct ExplorationProgress: View {
    @EnvironmentObject var userData: UserData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Exploration Progress")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
                .padding(.horizontal, 20)
                .textCase(.uppercase)
                .tracking(1)
                .accessibilityAddTraits(.isHeader)
            
            ScrollView(.horizontal, showsIndicators: false) {
                GlassEffectContainer {
                    HStack(spacing: 12) {
                        MetadataCard(
                            icon: "circle.hexagongrid",
                            value: "\(userData.conceptsExploredCount) / 3",
                            label: "Concepts",
                            sublabel: "Explored"
                        )
                        
                        MetadataCard(
                            icon: "clock",
                            value: formatDuration(userData.timeWalkDuration),
                            label: "Relative",
                            sublabel: "Time"
                        )
                        
                        MetadataCard(
                            icon: "arrow.left.arrow.right",
                            value: "\(userData.referenceFrameSwitches)",
                            label: "Reference",
                            sublabel: "Switches"
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        if minutes == 0 {
            return "< 1 min"
        }
        return "\(minutes) min"
    }
}

struct MetadataCard: View {
    let icon: String
    let value: String
    let label: String
    let sublabel: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(.cyan.opacity(0.5))
            
            Text(value)
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.white.opacity(0.4))
                Text(sublabel)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding(16)
        .frame(width: 110, height: 110)
        .glassEffect(.clear, in: .rect(cornerRadius: 24))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(sublabel): \(value)")
    }
}

// MARK: - Haptic Helper

@MainActor
private func triggerHaptic() {
    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    impactFeedback.impactOccurred()
}

#Preview {
    HomeView()
        .environmentObject(UserData())
}
