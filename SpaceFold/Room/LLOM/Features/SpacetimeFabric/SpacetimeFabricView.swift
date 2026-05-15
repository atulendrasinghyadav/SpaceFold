import SwiftUI
import ARKit
import RealityKit
import TipKit
import UIKit

// MARK: - Educational Tips

struct PlacementTip: Tip {
    var title: Text {
        Text("Find a Flat Surface")
    }
    var message: Text? {
        Text("Point your camera at a table or floor to place the spacetime grid")
    }
    var image: Image? {
        Image(systemName: "square.grid.3x3")
    }
}

struct MassTip: Tip {
    var title: Text {
        Text("Add Mass to Curve Space")
    }
    var message: Text? {
        Text("Drag the purple sphere onto the grid. Mass bends spacetime around it!")
    }
    var image: Image? {
        Image(systemName: "circle.fill")
    }
}

struct PinchTip: Tip {
    var title: Text {
        Text("Change the Mass")
    }
    var message: Text? {
        Text("Pinch to make the mass bigger or smaller. Heavier objects curve space more!")
    }
    var image: Image? {
        Image(systemName: "hand.pinch")
    }
}

struct ParticleTip: Tip {
    var title: Text {
        Text("Release Light")
    }
    var message: Text? {
        Text("Tap the grid to release a light particle. Watch how it follows the curved spacetime!")
    }
    var image: Image? {
        Image(systemName: "sparkle")
    }
}

// MARK: - Toast Message System

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let duration: Double
    
    static func == (lhs: ToastMessage, rhs: ToastMessage) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Main View

struct SpacetimeFabricView: View {
    @StateObject private var coordinator = SpacetimeARCoordinator()
    
    @State private var showInstruction = false
    @State private var showLearning = false
    @State private var showControls = false
    @State private var currentToast: ToastMessage?
    @State private var toastQueue: [ToastMessage] = []
    @State private var hasShownMassTip = false
    @State private var hasShownPinchTip = false
    @State private var hasShownParticleTip = false
    @State private var showChat = false
    
    // Tips
    let placementTip = PlacementTip()
    let massTip = MassTip()
    let pinchTip = PinchTip()
    let particleTip = ParticleTip()
    
    var body: some View {
        ZStack {
            // AR View
            SpacetimeFabricARViewContainer(coordinator: coordinator)
                .ignoresSafeArea()
            
            // UI Overlay
            VStack(spacing: 0) {
                // Top instruction with TipKit style
                if !coordinator.instructionText.isEmpty {
                    InstructionLabel(text: coordinator.instructionText)
                        .opacity(showInstruction ? 1 : 0)
                        .animation(.easeInOut(duration: 0.8), value: showInstruction)
                        .padding(.top, 16)
                }
                
                // Toast notification area
                if let toast = currentToast {
                    ToastView(message: toast)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity
                        ))
                        .padding(.top, 8)
                }
                
                Spacer()
                
                // Educational insight (bottom center)
                if coordinator.showLearningPrompt {
                    EducationalInsightView(text: coordinator.learningText)
                        .opacity(showLearning ? 1 : 0)
                        .animation(.easeInOut(duration: 1.2), value: showLearning)
                        .padding(.bottom, 16)
                }
                
                // Particle release hint
                if coordinator.state == .interactive && !hasShownParticleTip {
                    HintLabel(text: "💡 Tap empty space to release a light particle")
                        .padding(.bottom, 8)
                }
                
                // Visualization Controls
                if showControls {
                    VisualizationControls(coordinator: coordinator, onModeChange: { mode in
                        showToast(forMode: mode)
                    })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationTitle("Spacetime Fabric")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showChat = true
                } label: {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.cyan)
                }
                .accessibilityLabel("Ask SpaceFold AI")
                .accessibilityHint("Opens the AI chat assistant for spacetime fabric")
            }
        }
        .sheet(isPresented: $showChat) {
            NavigationStack {
                SpaceFoldChatView(contextHint: "spacetime_fabric")
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Done") { showChat = false }
                                .foregroundStyle(.cyan)
                        }
                    }
            }
            .preferredColorScheme(.dark)
        }
        .task {
            // Configure TipKit
            try? Tips.configure([
                .displayFrequency(.immediate),
                .datastoreLocation(.applicationDefault)
            ])
        }
        .onAppear {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                showInstruction = true
            }
            // Show initial educational toast
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                queueToast(ToastMessage(
                    icon: "🌌",
                    title: "Einstein's Insight",
                    subtitle: "Mass tells spacetime how to curve",
                    duration: 4
                ))
            }
        }
        .onChange(of: coordinator.state) { oldValue, newValue in
            handleStateChange(newValue)
        }
        .onChange(of: coordinator.showLearningPrompt) { oldValue, newValue in
            if newValue {
                withAnimation(.easeIn(duration: 0.8)) {
                    showLearning = true
                }
            }
        }
        .onDisappear {
            coordinator.cleanup()
        }
    }
    
    // MARK: - State Handling
    
    private func handleStateChange(_ state: SpacetimeARCoordinator.ARState) {
        switch state {
        case .planeDetected:
            queueToast(ToastMessage(
                icon: "✓",
                title: "Surface Found",
                subtitle: "Tap to place your spacetime grid",
                duration: 3
            ))
            
        case .gridPlaced:
            withAnimation(.easeInOut(duration: 0.5).delay(0.5)) {
                showControls = true
            }
            if !hasShownMassTip {
                hasShownMassTip = true
                queueToast(ToastMessage(
                    icon: "⚫",
                    title: "Mass Warps Space",
                    subtitle: "Drag the mass onto the grid to bend spacetime",
                    duration: 4
                ))
            }
            
        case .interactive:
            if !hasShownPinchTip {
                hasShownPinchTip = true
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2))
                    queueToast(ToastMessage(
                        icon: "🤏",
                        title: "Try Pinching",
                        subtitle: "Pinch to change mass — more mass = deeper curve",
                        duration: 4
                    ))
                }
            }
            if !hasShownParticleTip {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(5))
                    hasShownParticleTip = true
                    queueToast(ToastMessage(
                        icon: "✨",
                        title: "Light Follows Curves",
                        subtitle: "Tap to release light — it follows the curved spacetime",
                        duration: 4
                    ))
                }
            }
            
        default:
            break
        }
    }
    
    private func showToast(forMode mode: String) {
        if mode == "space" {
            queueToast(ToastMessage(
                icon: "🌙",
                title: "Space Mode",
                subtitle: "Imagine you're in deep space, seeing pure geometry",
                duration: 3
            ))
        } else if mode == "camera" {
            queueToast(ToastMessage(
                icon: "☀️",
                title: "Camera Mode",
                subtitle: "See spacetime curvature in the real world",
                duration: 3
            ))
        } else if mode == "curved" {
            queueToast(ToastMessage(
                icon: "◦◦◦",
                title: "Curved Space View",
                subtitle: "Points show how space bends around mass",
                duration: 3
            ))
        } else if mode == "assumed" {
            queueToast(ToastMessage(
                icon: "▢",
                title: "Flat Space View",
                subtitle: "Grid lines show the original flat spacetime",
                duration: 3
            ))
        }
    }
    
    // MARK: - Toast Queue
    
    private func queueToast(_ toast: ToastMessage) {
        toastQueue.append(toast)
        showNextToast()
    }
    
    private func showNextToast() {
        guard currentToast == nil, !toastQueue.isEmpty else { return }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            currentToast = toastQueue.removeFirst()
        }
        
        if let toast = currentToast {
            // Announce toast for VoiceOver
            UIAccessibility.post(
                notification: .announcement,
                argument: "\(toast.title): \(toast.subtitle)"
            )
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(toast.duration))
                withAnimation(.easeOut(duration: 0.3)) {
                    currentToast = nil
                }
                try? await Task.sleep(for: .milliseconds(400))
                showNextToast()
            }
        }
    }
}

// MARK: - Toast View

struct ToastView: View {
    let message: ToastMessage
    
    var body: some View {
        HStack(spacing: 12) {
            Text(message.icon)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(message.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                
                Text(message.subtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.white.opacity(0.7))
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.black.opacity(0.5))
                )
        )
        .padding(.horizontal, 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message.title): \(message.subtitle)")
    }
}

// MARK: - Educational Insight View

struct EducationalInsightView: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(.yellow)
                .font(.system(size: 16))
            
            Text(text)
                .font(.system(size: 15, weight: .medium, design: .serif))
                .italic()
                .foregroundStyle(.white.opacity(0.95))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.4))
                )
        )
        .padding(.horizontal, 24)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Physics insight: \(text)")
    }
}

// MARK: - Visualization Controls

struct VisualizationControls: View {
    @ObservedObject var coordinator: SpacetimeARCoordinator
    var onModeChange: (String) -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Grid Style Picker
            Picker("Grid Style", selection: $coordinator.gridStyle) {
                ForEach(SpacetimeARCoordinator.GridStyle.allCases, id: \.self) { style in
                    Text(style.rawValue).tag(style)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
            .accessibilityLabel("Grid visualization style")
            .accessibilityHint("Switches between dot grid and line grid views")
            .onChange(of: coordinator.gridStyle) { oldValue, newValue in
                coordinator.rebuildGrid()
                onModeChange(newValue == .dots ? "curved" : "assumed")
            }
            
            Spacer()
            
            // Space Mode Toggle
            Button {
                coordinator.toggleSpaceMode()
                onModeChange(coordinator.spaceMode ? "space" : "camera")
            } label: {
                Image(systemName: coordinator.spaceMode ? "moon.stars.fill" : "sun.max.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(coordinator.spaceMode ? .cyan : .yellow)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                    )
            }
            .accessibilityLabel(coordinator.spaceMode ? "Space mode active" : "Camera mode active")
            .accessibilityHint("Switches between camera feed and deep space background")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.3))
                )
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - AR View Container

struct SpacetimeFabricARViewContainer: UIViewRepresentable {
    let coordinator: SpacetimeARCoordinator
    
    func makeCoordinator() -> CoachingCoordinator {
        CoachingCoordinator()
    }
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.environment.background = .cameraFeed()
        coordinator.setupAR(arView)
        
        // Add Apple's built-in AR Coaching Overlay
        let coachingOverlay = ARCoachingOverlayView()
        coachingOverlay.session = arView.session as ARSession?
        coachingOverlay.goal = .horizontalPlane
        coachingOverlay.activatesAutomatically = true
        coachingOverlay.delegate = context.coordinator
        coachingOverlay.translatesAutoresizingMaskIntoConstraints = false
        arView.addSubview(coachingOverlay)
        
        NSLayoutConstraint.activate([
            coachingOverlay.topAnchor.constraint(equalTo: arView.topAnchor),
            coachingOverlay.leadingAnchor.constraint(equalTo: arView.leadingAnchor),
            coachingOverlay.trailingAnchor.constraint(equalTo: arView.trailingAnchor),
            coachingOverlay.bottomAnchor.constraint(equalTo: arView.bottomAnchor)
        ])
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
    
    // Coaching delegate
    class CoachingCoordinator: NSObject, ARCoachingOverlayViewDelegate {
        func coachingOverlayViewWillActivate(_ coachingOverlayView: ARCoachingOverlayView) {
            // Coaching started — overlay is visible
        }
        
        func coachingOverlayViewDidDeactivate(_ coachingOverlayView: ARCoachingOverlayView) {
            // Coaching finished — surface detected, overlay auto-hides
        }
        
        func coachingOverlayViewDidRequestSessionReset(_ coachingOverlayView: ARCoachingOverlayView) {
            // User requested session reset from coaching UI
            Task { @MainActor in
                coachingOverlayView.session?.run(ARWorldTrackingConfiguration(), options: [.resetTracking, .removeExistingAnchors])
            }
        }
    }
}

// MARK: - Instruction Label

struct InstructionLabel: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 14))
                .foregroundStyle(.cyan)
            
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.3))
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Instruction: \(text)")
    }
}

// MARK: - Hint Label

struct HintLabel: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(.white.opacity(0.6))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.3))
            )
        .accessibilityLabel(text)
    }
}

#Preview {
    SpacetimeFabricView()
}
