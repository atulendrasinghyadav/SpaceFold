import SwiftUI
import RealityKit
import ARKit

// MARK: - Time Walk View (Full AR Experience)

struct TimeWalkView: View {
    @EnvironmentObject var userData: UserData
    @State private var startTime: Date?
    @StateObject private var coordinator = TimeDilationARCoordinator()
    @State private var showTips = true
    @State private var velocity: Float = 0
    @State private var showChat = false
    
    var body: some View {
        ZStack {
            // Full-screen AR View
            TimeDilationARViewContainer(coordinator: coordinator)
                .ignoresSafeArea()
            
            // UI Overlays
            VStack(spacing: 0) {
                // Tips Box (top)
                if showTips {
                    TipsBox(onDismiss: { 
                        withAnimation(.easeOut(duration: 0.3)) {
                            showTips = false 
                        }
                    })
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                Spacer()
                
                // Bottom Controls
                VStack(spacing: 16) {
                    // Mode Controls Row
                    HStack(spacing: 12) {
                        // Perspective Toggle
                        PerspectiveToggle(perspective: $coordinator.perspective)
                        
                        Spacer()
                        
                        // Space Mode Toggle
                        Button {
                            coordinator.toggleSpaceMode()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: coordinator.spaceMode ? "moon.stars.fill" : "camera.fill")
                                    .font(.system(size: 14, weight: .medium))
                                Text(coordinator.spaceMode ? "Space" : "Camera")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundStyle(coordinator.spaceMode ? .cyan : .yellow)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial)
                            )
                        }
                        .accessibilityLabel(coordinator.spaceMode ? "Space mode active" : "Camera mode active")
                        .accessibilityHint("Switches between camera feed and deep space background")
                    }
                    
                    // Time & Speed Display with Reset
                    TimeSpeedDisplay(
                        earthTime: coordinator.earthTime,
                        rocketTime: coordinator.rocketTime,
                        velocity: velocity,
                        gamma: coordinator.gamma,
                        onReset: {
                            coordinator.reset()
                        }
                    )
                    
                    // Velocity Slider
                    VelocitySliderControl(velocity: $velocity) { newValue in
                        coordinator.setVelocity(newValue)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea(edges: .bottom)
                )
            }
        }
        .navigationTitle("Time Walk")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
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
                .accessibilityHint("Opens the AI chat assistant for time dilation")
            }
        }
        .sheet(isPresented: $showChat) {
            NavigationStack {
                SpaceFoldChatView(contextHint: "time_dilation")
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Done") { showChat = false }
                                .foregroundStyle(.cyan)
                        }
                    }
            }
            .preferredColorScheme(.dark)
        }
        .animation(.easeInOut(duration: 0.3), value: showTips)
        .onAppear {
            startTime = Date()
        }
        .onDisappear {
            if let start = startTime {
                let duration = Date().timeIntervalSince(start)
                userData.addTimeWalkDuration(duration)
            }
            coordinator.cleanup()
        }
    }
}

// MARK: - AR View Container

struct TimeDilationARViewContainer: UIViewRepresentable {
    let coordinator: TimeDilationARCoordinator
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.environment.background = .cameraFeed()
        coordinator.setupAR(arView)
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
}

// MARK: - Tips Box

struct TipsBox: View {
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                    .font(.system(size: 16))
                Text("What is Time Dilation?")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Dismiss tip")
                .accessibilityHint("Closes the educational tip about time dilation")
            }
            
            Text("As objects move faster, time passes slower for them. Use the slider to change the rocket's velocity and watch how its clock slows compared to Earth!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.regularMaterial)
        )
    }
}

// MARK: - Perspective Toggle

struct PerspectiveToggle: View {
    @Binding var perspective: Perspective
    
    var body: some View {
        HStack(spacing: 8) {
            Text("VIEW")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            
            Picker("Perspective", selection: $perspective) {
                Label("Earth", systemImage: "globe.americas.fill")
                    .tag(Perspective.earth)
                Label("Rocket", systemImage: "airplane")
                    .tag(Perspective.rocket)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 200)
            .accessibilityLabel("Observer perspective")
            .accessibilityHint("Switch between Earth and Rocket viewpoints")
        }
    }
}

// MARK: - Time & Speed Display

struct TimeSpeedDisplay: View {
    let earthTime: Double
    let rocketTime: Double
    let velocity: Float
    let gamma: Double
    let onReset: () -> Void
    
    var body: some View {
        HStack(spacing: 20) {
            // Earth Time
            TimeCard(icon: "🌍", label: "Earth", time: earthTime, color: .blue)
            
            // Rocket Time
            TimeCard(icon: "🚀", label: "Rocket", time: rocketTime, color: .orange)
            
            Spacer()
            
            // Speed & Reset
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.2fc", velocity))
                    .font(.system(.title3, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundStyle(.cyan)
                
                Text("γ = \(String(format: "%.1f", gamma))")
                    .font(.caption)
                    .foregroundStyle(.purple)
            }
            
            // Reset Button
            Button(action: onReset) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.primary)
                    .padding(10)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            .accessibilityLabel("Reset simulation")
            .accessibilityHint("Resets Earth and rocket clocks to zero")
        }
    }
}

struct TimeCard: View {
    let icon: String
    let label: String
    let time: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(icon)
                .font(.title3)
            Text(String(format: "%.1fs", time))
                .font(.system(.subheadline, design: .monospaced))
                .fontWeight(.medium)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) clock: \(String(format: "%.1f", time)) seconds")
    }
}

// MARK: - Velocity Slider

struct VelocitySliderControl: View {
    @Binding var velocity: Float
    let onChanged: (Float) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Text("0")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Slider(value: $velocity, in: 0...0.99) { _ in }
                .onChange(of: velocity) { _, newValue in
                    onChanged(newValue)
                }
                .tint(.cyan)
                .accessibilityLabel("Rocket velocity")
                .accessibilityValue("\(Int(velocity * 100)) percent of light speed")
            
            Text("c")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.red)
        }
    }
}

// MARK: - Perspective Enum

enum Perspective: String, CaseIterable {
    case earth
    case rocket
}

// MARK: - Preview

#Preview {
    TimeWalkView()
}
