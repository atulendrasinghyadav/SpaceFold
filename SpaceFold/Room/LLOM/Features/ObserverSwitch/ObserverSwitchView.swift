import SwiftUI
import ARKit
import RealityKit
import TipKit
import UIKit

// MARK: - Educational Tip

struct ObserverFrameTip: Tip {
    var title: Text {
        Text("Motion is Relative")
    }
    var message: Text? {
        Text("A ball thrown inside a moving train looks different depending on where you stand. The platform observer sees a parabolic arc, while the train observer sees a straight line!")
    }
    var image: Image? {
        Image(systemName: "eye.trianglebadge.exclamationmark")
    }
}

// MARK: - Observer Switch View

struct ObserverSwitchView: View {
    @EnvironmentObject var userData: UserData
    @StateObject private var coordinator = ObserverFramesARCoordinator()
    @State private var showTip = true
    @State private var showChat = false
    
    private let observerTip = ObserverFrameTip()
    
    var body: some View {
        ZStack {
            // AR View
            ObserverFramesARViewContainer(coordinator: coordinator)
                .ignoresSafeArea()
            
            // UI Overlay
            VStack(spacing: 0) {
                // Tip Box (top)
                if showTip {
                    ObserverTipBox(onDismiss: {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showTip = false
                        }
                    })
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                // Instruction badge
                if coordinator.showInstruction {
                    InstructionBadge(text: coordinator.instructionText)
                        .padding(.top, 12)
                        .transition(.opacity)
                }
                
                Spacer()
                
                // Bottom Controls
                VStack(spacing: 14) {
                    // Path description label
                    HStack(spacing: 8) {
                        Image(systemName: coordinator.currentObserver == .platform ? "point.topleft.down.to.point.bottomright.curvepath" : "arrow.up.arrow.down")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(coordinator.currentObserver == .platform ? .orange : .cyan)
                        
                        Text(coordinator.pathDescription)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
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
                    .accessibilityLabel("Ball path: \(coordinator.pathDescription)")
                    
                    // Controls Row: Perspective + Space Toggle
                    HStack(spacing: 12) {
                        // Observer Perspective Picker
                        ObserverPerspectivePicker(
                            currentObserver: coordinator.currentObserver,
                            onSelect: { newObserver in
                                if newObserver != coordinator.currentObserver {
                                    coordinator.switchObserver(to: newObserver)
                                    userData.incrementReferenceFrameSwitches()
                                    UIAccessibility.post(
                                        notification: .announcement,
                                        argument: "Switched to \(newObserver.rawValue) observer"
                                    )
                                }
                            }
                        )
                        
                        Spacer()
                        
                        // Camera / Space Toggle
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
                    
                    // Tap hint
                    if coordinator.ballState == .landed {
                        Text("Tap to throw the ball again")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(.white.opacity(0.5))
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.black.opacity(0.3))
                        )
                        .ignoresSafeArea(edges: .bottom)
                )
            }
        }
        .navigationTitle("Observer Frames")
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
                .accessibilityHint("Opens the AI chat assistant for observer frames")
            }
        }
        .sheet(isPresented: $showChat) {
            NavigationStack {
                SpaceFoldChatView(contextHint: "observer_frames")
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Done") { showChat = false }
                                .foregroundStyle(.cyan)
                        }
                    }
            }
            .preferredColorScheme(.dark)
        }
        .animation(.easeInOut(duration: 0.3), value: showTip)
        .animation(.easeInOut(duration: 0.3), value: coordinator.currentObserver)
        .animation(.easeInOut(duration: 0.3), value: coordinator.ballState)
        .animation(.easeInOut(duration: 0.3), value: coordinator.spaceMode)
        .onDisappear {
            coordinator.cleanup()
        }
    }
}

// MARK: - AR View Container

struct ObserverFramesARViewContainer: UIViewRepresentable {
    let coordinator: ObserverFramesARCoordinator
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.environment.background = .cameraFeed()
        coordinator.setupAR(arView)
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
}

// MARK: - Tip Box

struct ObserverTipBox: View {
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "eye.trianglebadge.exclamationmark")
                    .foregroundStyle(.cyan)
                    .font(.system(size: 16))
                Text("Motion is Relative")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Dismiss tip")
                .accessibilityHint("Closes the educational tip about relative motion")
            }
            
            Text("A ball thrown inside a moving train looks different depending on where you stand. Switch between **Platform** and **Train** to see how the same throw appears from each frame of reference!")
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

// MARK: - Observer Perspective Picker

struct ObserverPerspectivePicker: View {
    let currentObserver: ObserverFramesARCoordinator.Observer
    let onSelect: (ObserverFramesARCoordinator.Observer) -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(ObserverFramesARCoordinator.Observer.allCases, id: \.self) { observer in
                observerButton(for: observer)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 11)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 11)
                        .fill(Color.black.opacity(0.4))
                )
        )
        .frame(maxWidth: 220)
    }
    
    @ViewBuilder
    private func observerButton(for observer: ObserverFramesARCoordinator.Observer) -> some View {
        let isActive = currentObserver == observer
        let iconName = observer == .platform ? "figure.stand" : "tram.fill"
        let bgColor: Color = observer == .platform ? .orange : .cyan
        
        Button {
            onSelect(observer)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: iconName)
                    .font(.system(size: 12))
                Text(observer.rawValue)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(isActive ? .white : .white.opacity(0.5))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                Group {
                    if isActive {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(bgColor.opacity(0.8))
                    }
                }
            )
        }
        .accessibilityLabel("\(observer.rawValue) observer")
        .accessibilityHint(observer == .platform ? "See the ball path from the platform" : "See the ball path from inside the train")
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

// MARK: - Instruction Badge (reuse pattern)

private struct InstructionBadge: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .background(Capsule().fill(Color.black.opacity(0.3)))
            )
            .accessibilityLabel("Instruction: \(text)")
    }
}

// MARK: - Preview

#Preview {
    ObserverSwitchView()
}
