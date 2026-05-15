import SwiftUI
import ARKit
import RealityKit
import Combine

/// Manages AR session for Observer Frames — Ball-in-Train relative motion experiment
@MainActor

final class ObserverFramesARCoordinator: NSObject, ObservableObject {
    
    // MARK: - State
    
    enum Observer: String, CaseIterable, Sendable {
        case platform = "Platform"
        case train = "Train"
    }
    
    enum BallState: Equatable, Sendable {
        case idle
        case animating
        case landed
    }
    
    @Published var currentObserver: Observer = .platform
    @Published var ballState: BallState = .idle
    @Published var spaceMode: Bool = false
    @Published var showInstruction: Bool = true
    @Published var instructionText: String = "Watch the ball from different perspectives"
    
    /// Description of the current ball trajectory
    var pathDescription: String {
        switch currentObserver {
        case .platform: return "Parabolic Path"
        case .train: return "Straight Line"
        }
    }
    
    // MARK: - AR Entities
    
    weak var arView: ARView?
    private var sceneAnchor: AnchorEntity?
    
    // Scene entities
    private var trainEntity: Entity?
    private var platformEntity: Entity?
    private var trackEntity: Entity?
    private var ballEntity: ModelEntity?
    private var trailEntities: [Entity] = []
    private var windowFrameEntity: Entity?
    
    // MARK: - Animation
    
    private var displayLink: CADisplayLink?
    private var animationTime: Float = 0
    private var isAnimating: Bool = false
    
    // MARK: - Constants
    
    private let sceneDistance: Float = 0.9
    private let trainWidth: Float = 0.35
    private let trainHeight: Float = 0.12
    private let trainDepth: Float = 0.08
    private let platformWidth: Float = 0.5
    private let ballRadius: Float = 0.015
    private let throwDuration: Float = 1.8   // seconds for full throw
    private let throwHeight: Float = 0.22     // how high the ball goes
    private let trainSpeed: Float = 0.15      // train horizontal speed (m/s)
    private var trainTravelDistance: Float { trainSpeed * throwDuration }  // total distance train covers
    
    /// Base train position (Y)
    private let trainBaseY: Float = -0.1
    /// Base train position (X) — starting X for platform frame
    private var trainStartX: Float { -trainTravelDistance / 2 }
    
    // MARK: - Setup
    
    func setupAR(_ arView: ARView) {
        self.arView = arView
        
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = []
        config.environmentTexturing = .automatic
        arView.session.run(config)
        
        // Create scene after a short delay
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            self?.createScene()
        }
        
        startAnimationLoop()
        
        // Tap to throw ball
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        arView.addGestureRecognizer(tap)
    }
    
    // MARK: - Scene Creation
    
    private func createScene() {
        guard let arView = arView else { return }
        
        let anchor = AnchorEntity(world: [0, 0, -sceneDistance])
        arView.scene.addAnchor(anchor)
        sceneAnchor = anchor
        
        // Create tracks / ground
        let track = createTrackEntity()
        track.position = SIMD3<Float>(0, -0.18, 0)
        anchor.addChild(track)
        trackEntity = track
        
        // Create platform
        let platform = createPlatformEntity()
        platform.position = SIMD3<Float>(0, -0.25, 1.1)
        anchor.addChild(platform)
        platformEntity = platform
        
        // Create train
        let train = createTrainEntity()
        train.position = SIMD3<Float>(0, -0.1, 0)
        anchor.addChild(train)
        trainEntity = train
        
        // Create ball inside the train
        let ball = createBallEntity()
        ball.position = SIMD3<Float>(0, -0.04, 0)
        anchor.addChild(ball)
        ballEntity = ball
        
        // Auto-throw after 2 seconds
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            self?.throwBall()
        }
        
        // Fade instruction
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(4))
            withAnimation(.easeOut(duration: 0.8)) {
                self?.instructionText = "Tap to throw the ball again"
            }
        }
    }
    
    // MARK: - Entity Builders
    
    private func createTrackEntity() -> Entity {
        let parent = Entity()
        
        // Two rails
        let railMesh = MeshResource.generateBox(width: 0.6, height: 0.005, depth: 0.005, cornerRadius: 0.001)
        var railMaterial = SimpleMaterial()
        railMaterial.color = .init(tint: UIColor.darkGray.withAlphaComponent(0.7))
        railMaterial.metallic = .float(0.8)
        railMaterial.roughness = .float(0.3)
        
        let rail1 = ModelEntity(mesh: railMesh, materials: [railMaterial])
        rail1.position = SIMD3<Float>(0, 0, 0.02)
        parent.addChild(rail1)
        
        let rail2 = ModelEntity(mesh: railMesh, materials: [railMaterial])
        rail2.position = SIMD3<Float>(0, 0, -0.02)
        parent.addChild(rail2)
        
        // Sleepers (crossties)
        let sleeperMesh = MeshResource.generateBox(width: 0.02, height: 0.003, depth: 0.06, cornerRadius: 0.001)
        var sleeperMaterial = SimpleMaterial()
        sleeperMaterial.color = .init(tint: UIColor.brown.withAlphaComponent(0.6))
        sleeperMaterial.roughness = .float(0.8)
        
        for i in -6...6 {
            let sleeper = ModelEntity(mesh: sleeperMesh, materials: [sleeperMaterial])
            sleeper.position = SIMD3<Float>(Float(i) * 0.045, -0.003, 0)
            parent.addChild(sleeper)
        }
        
        return parent
    }
    
    private func createPlatformEntity() -> Entity {
        let mesh = MeshResource.generateBox(width: 4, height: 0.1, depth: 2, cornerRadius: 0.005)
        var material = SimpleMaterial()
        material.color = .init(tint: UIColor.systemGray3.withAlphaComponent(0.7))
        material.metallic = .float(0.2)
        material.roughness = .float(0.8)
        return ModelEntity(mesh: mesh, materials: [material])
    }
    
    private func createTrainEntity() -> Entity {
        let parent = Entity()
        
        // Train body
        let bodyMesh = MeshResource.generateBox(width: trainWidth, height: trainHeight, depth: trainDepth, cornerRadius: 0.01)
        var bodyMaterial = SimpleMaterial()
        bodyMaterial.color = .init(tint: UIColor(red: 0.15, green: 0.25, blue: 0.75, alpha: 0.85))
        bodyMaterial.metallic = .float(0.7)
        bodyMaterial.roughness = .float(0.3)
        
        let body = ModelEntity(mesh: bodyMesh, materials: [bodyMaterial])
        parent.addChild(body)
        
        // Roof accent
        let roofMesh = MeshResource.generateBox(width: trainWidth * 0.95, height: 0.015, depth: trainDepth * 0.85, cornerRadius: 0.007)
        var roofMaterial = SimpleMaterial()
        roofMaterial.color = .init(tint: UIColor(red: 0.2, green: 0.35, blue: 0.9, alpha: 0.9))
        roofMaterial.metallic = .float(0.6)
        roofMaterial.roughness = .float(0.4)
        
        let roof = ModelEntity(mesh: roofMesh, materials: [roofMaterial])
        roof.position = SIMD3<Float>(0, trainHeight / 2 + 0.007, 0)
        parent.addChild(roof)
        
        // Window frame (visible through-hole effect)
        let windowMesh = MeshResource.generateBox(width: 0.08, height: 0.05, depth: trainDepth + 0.01, cornerRadius: 0.005)
        var windowMaterial = SimpleMaterial()
        windowMaterial.color = .init(tint: UIColor.cyan.withAlphaComponent(0.15))
        windowMaterial.metallic = .float(0.9)
        windowMaterial.roughness = .float(0.1)
        
        let window = ModelEntity(mesh: windowMesh, materials: [windowMaterial])
        window.position = SIMD3<Float>(0, 0.01, 0)
        parent.addChild(window)
        windowFrameEntity = window
        
        // Window border for visibility
        let borderMesh = MeshResource.generateBox(width: 0.09, height: 0.06, depth: 0.002, cornerRadius: 0.008)
        var borderMaterial = SimpleMaterial()
        borderMaterial.color = .init(tint: UIColor.cyan.withAlphaComponent(0.5))
        borderMaterial.metallic = .float(0.5)
        
        let border = ModelEntity(mesh: borderMesh, materials: [borderMaterial])
        border.position = SIMD3<Float>(0, 0.01, trainDepth / 2 + 0.002)
        parent.addChild(border)
        
        // Wheels
        let wheelMesh = MeshResource.generateSphere(radius: 0.012)
        var wheelMaterial = SimpleMaterial()
        wheelMaterial.color = .init(tint: UIColor.darkGray)
        wheelMaterial.metallic = .float(0.9)
        wheelMaterial.roughness = .float(0.2)
        
        let positions: [SIMD3<Float>] = [
            SIMD3<Float>(-trainWidth / 2 + 0.04, -trainHeight / 2 - 0.005, 0),
            SIMD3<Float>(trainWidth / 2 - 0.04, -trainHeight / 2 - 0.005, 0)
        ]
        
        for pos in positions {
            let wheel = ModelEntity(mesh: wheelMesh, materials: [wheelMaterial])
            wheel.position = pos
            parent.addChild(wheel)
        }
        
        return parent
    }
    
    private func createBallEntity() -> ModelEntity {
        let mesh = MeshResource.generateSphere(radius: ballRadius)
        var material = SimpleMaterial()
        material.color = .init(tint: .systemOrange)
        material.metallic = .float(0.4)
        material.roughness = .float(0.6)
        
        let ball = ModelEntity(mesh: mesh, materials: [material])
        
        // Glow
        let glowMesh = MeshResource.generateSphere(radius: ballRadius * 1.4)
        var glowMaterial = SimpleMaterial()
        glowMaterial.color = .init(tint: UIColor.orange.withAlphaComponent(0.25))
        let glow = ModelEntity(mesh: glowMesh, materials: [glowMaterial])
        ball.addChild(glow)
        
        return ball
    }
    
    // MARK: - Ball Throw Animation
    
    func throwBall() {
        guard !isAnimating else { return }
        
        isAnimating = true
        ballState = .animating
        animationTime = 0
        
        // Clear previous trail
        for trail in trailEntities {
            trail.removeFromParent()
        }
        trailEntities.removeAll()
        
        // Reset positions before throw
        resetEntityPositions()
        
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }
    
    /// Reset train and ball to their starting positions for the current observer
    private func resetEntityPositions() {
        switch currentObserver {
        case .platform:
            // Train starts at left side and will travel right
            trainEntity?.position.x = trainStartX
        case .train:
            // Train stays centered
            trainEntity?.position.x = trainStartX
        }
        trainEntity?.position.y = trainBaseY
        
        // Ball starts at center above train floor
        ballEntity?.position = SIMD3<Float>(0, -0.04, 0)
    }
    
    /// Compute ball position at time t — always a straight up-and-down throw
    /// The visual difference between observers comes from train movement, not ball path.
    private func ballPosition(at t: Float) -> SIMD3<Float> {
        // Normalised time 0…1
        let progress = t / throwDuration
        guard progress <= 1.0 else { return SIMD3<Float>(0, -0.04, 0) }
        
        // Vertical: classic projectile  y = h₀ + v₀t - ½gt²
        // Peak at t = 0.5 → y_max = throwHeight
        // y(p) = -4 * throwHeight * (p - 0.5)² + throwHeight + baseY
        let baseY: Float = -0.04
        let y = -4 * throwHeight * (progress - 0.5) * (progress - 0.5) + throwHeight + baseY
        
        // Ball always goes straight up and down (same animation for both observers)
        return SIMD3<Float>(0, y, 0)
    }
    
    // MARK: - Observer Switching
    
    func switchObserver(to observer: Observer) {
        guard observer != currentObserver else { return }
        currentObserver = observer
        
        // Reset ball and re-throw
        isAnimating = false
        ballState = .idle

        // Clear trail
        for trail in trailEntities {
            trail.removeFromParent()
        }
        trailEntities.removeAll()
        
        // Reset entity positions for new observer
        resetEntityPositions()
        
        // Adjust camera angle
        updateCameraPerspective()
        
        // Re-throw after camera transition starts
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            self?.throwBall()
        }
        
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
    
    private func updateCameraPerspective() {
        guard let anchor = sceneAnchor else { return }
        
        // Platform: angled side-view (~15°) like watching from a platform
        // Train: head-on view (0°) like being inside the train
        let currentAngle = anchor.orientation.angle
        let targetAngle: Float = currentObserver == .train ? 1.57 : 0
        
        // Also adjust Z position — train frame slightly closer
        let targetZ: Float = currentObserver == .platform ? (-sceneDistance + 1) : -sceneDistance + 1
        
        animateCameraTransition(
            anchor: anchor,
            currentAngle: currentAngle,
            targetAngle: targetAngle,
            currentZ: anchor.position.z,
            targetZ: targetZ
        )
        
        // Show/hide window highlight
        if let window = windowFrameEntity as? ModelEntity {
            var mat = SimpleMaterial()
            if currentObserver == .platform {
                mat.color = .init(tint: UIColor.cyan.withAlphaComponent(0.2))
            } else {
                mat.color = .init(tint: UIColor.cyan.withAlphaComponent(0.05))
            }
            mat.metallic = .float(0.9)
            mat.roughness = .float(0.1)
            window.model?.materials = [mat]
        }
    }
    
    /// Smoothly animate both rotation and position of the scene anchor
    private func animateCameraTransition(
        anchor: AnchorEntity,
        currentAngle: Float,
        targetAngle: Float,
        currentZ: Float,
        targetZ: Float
    ) {
        let lerpFactor: Float = 0.1
        let newAngle = currentAngle + (targetAngle - currentAngle) * lerpFactor
        let newZ = currentZ + (targetZ - currentZ) * lerpFactor
        
        anchor.orientation = simd_quatf(angle: newAngle, axis: [0, 1, 0])
        anchor.position.z = newZ
        
        // Stop when close enough
        if abs(targetAngle - newAngle) < 0.001 && abs(targetZ - newZ) < 0.001 {
            anchor.orientation = simd_quatf(angle: targetAngle, axis: [0, 1, 0])
            anchor.position.z = targetZ
            return
        }
        
        Task { @MainActor [weak self, weak anchor] in
            try? await Task.sleep(for: .milliseconds(16))
            guard let anchor = anchor else { return }
            self?.animateCameraTransition(
                anchor: anchor,
                currentAngle: newAngle,
                targetAngle: targetAngle,
                currentZ: newZ,
                targetZ: targetZ
            )
        }
    }
    
    // MARK: - Space Mode Toggle
    
    /// Toggle between camera feed and dark space background
    func toggleSpaceMode() {
        spaceMode.toggle()
        if spaceMode {
            arView?.environment.background = .color(.black)
        } else {
            arView?.environment.background = .cameraFeed()
        }
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
    
    // MARK: - Animation Loop
    
    private func startAnimationLoop() {
        displayLink = CADisplayLink(target: self, selector: #selector(updateAnimation))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    @objc private func updateAnimation(_ displayLink: CADisplayLink) {
        guard isAnimating else { return }
        
        let dt = Float(displayLink.duration)
        animationTime += dt
        
        let progress = min(animationTime / throwDuration, 1.0)
        
        // Train always moves (same in both frames)
        let trainX = trainStartX + progress * trainTravelDistance
        trainEntity?.position.x = trainX
        
        if animationTime >= throwDuration {
            // Animation complete
            isAnimating = false
            ballState = .landed
            
            let ballLocal = ballPosition(at: throwDuration)
            // Ball rides with the train horizontally
            ballEntity?.position = SIMD3<Float>(trainX + ballLocal.x, ballLocal.y, ballLocal.z)
            return
        }
        
        // Ball throw is straight up/down — same for both perspectives
        let ballLocal = ballPosition(at: animationTime)
        // Offset ball by train's current X so ball moves with the train
        let ballWorld = SIMD3<Float>(trainX + ballLocal.x, ballLocal.y, ballLocal.z)
        ballEntity?.position = ballWorld
        
        // Leave trail dots every ~0.06s
        let trailInterval: Float = 0.06
        let trailIndex = Int(animationTime / trailInterval)
        
        if trailIndex > trailEntities.count {
            addTrailDot(at: ballWorld)
        }
    }
    
    private func addTrailDot(at position: SIMD3<Float>) {
        guard let anchor = sceneAnchor else { return }
        
        let dotMesh = MeshResource.generateSphere(radius: 0.004)
        var material = SimpleMaterial()
        material.color = .init(tint: UIColor.orange.withAlphaComponent(0.4))
        
        let dot = ModelEntity(mesh: dotMesh, materials: [material])
        dot.position = position
        anchor.addChild(dot)
        trailEntities.append(dot)
    }
    
    // MARK: - Gestures
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        if !isAnimating {
            throwBall()
        }
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        displayLink?.invalidate()
        displayLink = nil
        arView?.session.pause()
    }
}
