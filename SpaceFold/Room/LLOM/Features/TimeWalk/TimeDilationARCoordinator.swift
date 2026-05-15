import SwiftUI
import ARKit
import RealityKit
import CoreMotion
import Combine

/// Manages AR session for Time Dilation experience - Immersive, minimal, intuitive
@MainActor
final class TimeDilationARCoordinator: NSObject, ObservableObject {
    
    // MARK: - State
    
    enum ExperienceState: Equatable, Sendable {
        case scanning
        case establishing
        case ready
        case traveling
        case returning
        case complete
    }
    
    @Published var state: ExperienceState = .scanning
    
    // UI State
    @Published var instructionText: String = "Your frame of reference"
    @Published var showInstruction: Bool = false
    @Published var showLearning: Bool = false
    @Published var learningText: String = ""
    @Published var showReturnPrompt: Bool = false
    @Published var perspective: Perspective = .earth {
        didSet {
            updateCameraPerspective()
        }
    }
    @Published var spaceMode: Bool = false
    
    // Physics
    @Published var velocity: Float = 0.0
    @Published var earthTime: Double = 0.0
    @Published var rocketTime: Double = 0.0
    @Published var travelDuration: Float = 0.0
    @Published var displayGamma: Float = 1.0
    @Published var contractionFactor: Float = 1.0
    
    var gamma: Double {
        let v = Double(velocity)
        return 1.0 / sqrt(1.0 - v * v)
    }
    
    // Device motion
    @Published var deviceMotionOffset: SIMD3<Float> = .zero
    
    // MARK: - AR Entities
    
    weak var arView: ARView?
    private var sceneAnchor: AnchorEntity?
    private var rootEntity: Entity?
    
    // Model entities
    private var earthEntity: Entity?
    private var rocketEntity: Entity?
    private var flameEntity: Entity?
    
    // Clock entities
    private var earthClockEntity: Entity?
    private var rocketClockEntity: Entity?
    private var earthHandEntity: Entity?
    private var rocketHandEntity: Entity?
    private var starfieldEntities: [Entity] = []
    
    // MARK: - Animation
    
    private var displayLink: CADisplayLink?
    private var lastUpdateTime: CFTimeInterval = 0
    private var travelStartTime: Date?
    private var hasShownTwinParadox: Bool = false
    private var narrativeStep: Int = 0
    
    // MARK: - Motion
    
    private let motionManager = CMMotionManager()
    private var referenceAttitude: CMAttitude?
    
    // MARK: - Constants
    
    private let clockRadius: Float = 0.05
    private let sceneDistance: Float = 0.75
    private let starCount: Int = 400
    
    // MARK: - Setup
    
    func setupAR(_ arView: ARView) {
        self.arView = arView
        
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = []
        config.environmentTexturing = .automatic
        arView.session.run(config)
        arView.session.delegate = self
        
        startMotionTracking()
        
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            self.createScene()
        }
        
        startAnimationLoop()
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.8
        arView.addGestureRecognizer(longPress)
    }
    
    // MARK: - Scene Creation
    
    private func createScene() {
        guard let arView = arView else { return }
        
        let anchor = AnchorEntity(world: [0, 0, -sceneDistance])
        arView.scene.addAnchor(anchor)
        sceneAnchor = anchor
        
        // Create root entity to hold everything and allow camera movement simulation
        let root = Entity()
        root.position = SIMD3<Float>(0.15, 0, 0) // Initial offset for Earth perspective (Earth at -0.15)
        anchor.addChild(root)
        rootEntity = root
        
        // Create starfield
        createStarfield(parent: root)
        
        // Create Earth with clock on top
        createEarthWithClock(parent: root)
        
        // Create Rocket with flame and clock on top
        createRocketWithClock(parent: root)
        
        state = .establishing
        
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            withAnimation(.easeIn(duration: 1.0)) {
                self.showInstruction = true
            }
            
            try? await Task.sleep(for: .seconds(3))
            withAnimation(.easeOut(duration: 1.0)) {
                self.showInstruction = false
            }
            self.state = .ready
        }
    }
    
    // MARK: - Earth Model
    
    private func createEarthWithClock(parent: Entity) {
        let earthParent = Entity()
        earthParent.position = SIMD3<Float>(-0.15, -0.05, 0)
        
        // Earth sphere
        let sphereMesh = MeshResource.generateSphere(radius: 0.08)
        var earthMaterial = SimpleMaterial()
        
        // Try to generate texture, fallback to blue color if fails
        if let texture = generateEarthTexture() {
            earthMaterial.color = .init(texture: .init(texture))
            earthMaterial.roughness = .float(0.9) // Water is shiny
//            earthMaterial.metallic = .float(0.1)
        } else {
            earthMaterial.color = .init(tint: UIColor.systemBlue)
//            earthMaterial.metallic = .float(0.1)
            earthMaterial.roughness = .float(0.9)
        }
        
        let earthSphere = ModelEntity(mesh: sphereMesh, materials: [earthMaterial])
        earthParent.addChild(earthSphere)
        earthEntity = earthSphere
        
        // Earth clock on top
        let clock = createClockEntity(isEarth: true)
        clock.position = SIMD3<Float>(0, 0.15, 0)
        clock.orientation = simd_quatf(angle: .pi/2, axis: SIMD3<Float>(1, 0, 0))
        earthParent.addChild(clock)
        earthClockEntity = clock
        
        parent.addChild(earthParent)
    }
    
    // Procedural Earth Texture Generation
    private func generateEarthTexture() -> TextureResource? {
        let width = 1024
        let height = 512
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        
        let image = renderer.image { context in
            let ctx = context.cgContext
            
            // 1. Deep Ocean Background
            let oceanColor = UIColor(red: 0.05, green: 0.1, blue: 0.35, alpha: 1.0)
            oceanColor.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
            
            // 2. Draw Random Landmasses
            let landColor = UIColor(red: 0.15, green: 0.5, blue: 0.2, alpha: 1.0)
            landColor.setFill()
            
            // Create several irregular shapes
            for _ in 0..<12 {
                let centerX = Double.random(in: 0...Double(width))
                let centerY = Double.random(in: 0...Double(height))
                let size = Double.random(in: 50...150)
                
                ctx.move(to: CGPoint(x: centerX, y: centerY))
                
                // Draw blob by connecting random points around center
                let points = 8
                for i in 0...points {
                    let angle = (Double(i) / Double(points)) * .pi * 2
                    let radius = size * Double.random(in: 0.5...1.0)
                    let x = centerX + cos(angle) * radius
                    let y = centerY + sin(angle) * radius
                    
                    if i == 0 {
                        ctx.move(to: CGPoint(x: x, y: y))
                    } else {
                        ctx.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                ctx.closePath()
                ctx.fillPath()
            }
        }
        
        // Convert UIImage to TextureResource
        guard let cgImage = image.cgImage else { return nil }
        return try? TextureResource(image: cgImage, options: .init(semantic: .color))
    }
    
    // MARK: - Rocket Model
    
    private func createRocketWithClock(parent: Entity) {
        let rocketParent = Entity()
        rocketParent.position = SIMD3<Float>(0.15, -0.05, 0)
        
        // Rocket body (cylinder)
        let bodyMesh = MeshResource.generateCylinder(height: 0.12, radius: 0.025)
        var bodyMaterial = SimpleMaterial()
        bodyMaterial.color = .init(tint: UIColor.lightGray)
        bodyMaterial.metallic = .float(0.8)
        bodyMaterial.roughness = .float(0.3)
        
        let rocketBody = ModelEntity(mesh: bodyMesh, materials: [bodyMaterial])
        rocketParent.addChild(rocketBody)
        rocketEntity = rocketBody
        
        // Rocket nose cone
        let noseMesh = MeshResource.generateCone(height: 0.04, radius: 0.025)
        var noseMaterial = SimpleMaterial()
        noseMaterial.color = .init(tint: UIColor.red)
        noseMaterial.metallic = .float(0.5)
        
        let noseNode = ModelEntity(mesh: noseMesh, materials: [noseMaterial])
        noseNode.position = SIMD3<Float>(0, 0.08, 0)
        rocketParent.addChild(noseNode)
        
        // Rocket flame (cone pointing down from bottom of rocket)
        let flameMesh = MeshResource.generateCone(height: 0.04, radius: 0.025)
        var flameMaterial = SimpleMaterial()
        flameMaterial.color = .init(tint: UIColor.orange)
        flameMaterial.metallic = .float(0.0)
        flameMaterial.roughness = .float(1.0)
        
        let flame = ModelEntity(mesh: flameMesh, materials: [flameMaterial])
        // Position below rocket body, cone tip faces up by default so we flip it
        flame.position = SIMD3<Float>(0, -0.06, 0)
        rocketParent.addChild(flame)
        flameEntity = flame
        
        // Rocket clock on top
        let clock = createClockEntity(isEarth: false)
        clock.position = SIMD3<Float>(0, 0.18, 0)
        clock.orientation = simd_quatf(angle: .pi/2, axis: SIMD3<Float>(1, 0, 0))
        rocketParent.addChild(clock)
        rocketClockEntity = clock
        
        parent.addChild(rocketParent)
    }
    
    private func createClockEntity(isEarth: Bool) -> Entity {
        let parent = Entity()
        let faceColor: UIColor = isEarth ? UIColor.systemBlue.withAlphaComponent(0.3) : UIColor.systemOrange.withAlphaComponent(0.3)
        let handColor: UIColor = isEarth ? UIColor.white : UIColor.white
        let rimColor: UIColor = isEarth ? UIColor.systemBlue : UIColor.systemOrange
        
        // Clock face - visible disc
        let faceMesh = MeshResource.generateCylinder(height: 0.004, radius: clockRadius)
        var faceMaterial = SimpleMaterial()
        faceMaterial.color = .init(tint: faceColor)
        faceMaterial.metallic = .float(0.1)
        faceMaterial.roughness = .float(0.8)
        
        let faceEntity = ModelEntity(mesh: faceMesh, materials: [faceMaterial])
        parent.addChild(faceEntity)
        
        // Clock rim for visibility
        let rimMesh = MeshResource.generateCylinder(height: 0.006, radius: clockRadius + 0.003)
        var rimMaterial = SimpleMaterial()
        rimMaterial.color = .init(tint: rimColor.withAlphaComponent(0.2))
        rimMaterial.metallic = .float(0.5)
        rimMaterial.roughness = .float(0.4)
        
        let rimEntity = ModelEntity(mesh: rimMesh, materials: [rimMaterial])
        rimEntity.position.z = 0.001 // Slightly behind face
        parent.addChild(rimEntity)
        
        // Clock hand - more visible
        let handLength: Float = clockRadius * 0.75
        let handMesh = MeshResource.generateBox(width: 0.005, height: 0.003, depth: handLength)
        var handMaterial = SimpleMaterial()
        handMaterial.color = .init(tint: handColor)
        handMaterial.metallic = .float(0.3)
        handMaterial.roughness = .float(0.5)
        
        // Hand pivot container - rotates around Z axis
        let handPivot = Entity()
        let handEntity = ModelEntity(mesh: handMesh, materials: [handMaterial])
        // Position hand so it extends from center
        handEntity.position = SIMD3<Float>(0, 0, handLength / 2)
        handPivot.addChild(handEntity)
        // Position pivot at clock center, slightly in front of face
        handPivot.position = SIMD3<Float>(0, -0.005, 0)
        parent.addChild(handPivot)
        
        if isEarth {
            earthHandEntity = handPivot
        } else {
            rocketHandEntity = handPivot
        }
        
        // Center dot
        let centerMesh = MeshResource.generateSphere(radius: 0.006)
        var centerMaterial = SimpleMaterial()
        centerMaterial.color = .init(tint: rimColor)
        centerMaterial.metallic = .float(0.6)
        let centerEntity = ModelEntity(mesh: centerMesh, materials: [centerMaterial])
        centerEntity.position = SIMD3<Float>(0, -0.005, 0)
        parent.addChild(centerEntity)
        
        // Add hour markers for better clock visibility
        for i in 0..<12 {
            let angle = Float(i) * (.pi * 2 / 12)
            let markerMesh = MeshResource.generateSphere(radius: 0.004)
            var markerMaterial = SimpleMaterial()
            markerMaterial.color = .init(tint: handColor.withAlphaComponent(0.7))
            let marker = ModelEntity(mesh: markerMesh, materials: [markerMaterial])
            marker.position = SIMD3<Float>(
                sin(angle) * (clockRadius - 0.01),
                -0.003,
                cos(angle) * (clockRadius - 0.01)
            )
            parent.addChild(marker)
        }
        
        return parent
    }
    
    private func createStarfield(parent: Entity) {
        for _ in 0..<starCount {
            let star = createStarEntity()
            
            let theta = Float.random(in: 0..<Float.pi * 2)
            let phi = Float.random(in: 0..<Float.pi)
            let radius = Float.random(in: 0.8...5.0)
            
            star.position = SIMD3<Float>(
                radius * sin(phi) * cos(theta),
                radius * cos(phi),
                radius * sin(phi) * sin(theta) - 0.5
            )
            
            parent.addChild(star)
            starfieldEntities.append(star)
        }
    }
    
    private func createStarEntity() -> Entity {
        let size = Float.random(in: 0.001...0.004)
        let mesh = MeshResource.generateSphere(radius: size)
        var material = SimpleMaterial()
        let brightness = Float.random(in: 0.1...0.3)
        material.color = .init(tint: UIColor.white.withAlphaComponent(CGFloat(brightness)))
        material.metallic = .float(0.0)
        material.roughness = .float(1.0)
        
        return ModelEntity(mesh: mesh, materials: [material])
    }
    
    // MARK: - Visualization Controls
    
    /// Toggle between camera feed (Camera Mode) and dark space background (Space Mode)
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
    
    private func updateCameraPerspective() {
        guard let root = rootEntity else { return }
        
        let targetX: Float
        switch perspective {
        case .earth:
            // Earth is at -0.15, so we move root to +0.15 to center Earth
            targetX = 0.15
        case .rocket:
            // Rocket is at +0.15, so we move root to -0.15 to center Rocket
            targetX = -0.15
        }
        
        // Creating a transform for the new position
        var transform = root.transform
        transform.translation.x = targetX
        
        // Smoothly move the entire scene to center the selected object
        root.move(to: transform, relativeTo: root.parent, duration: 1.5, timingFunction: .easeInOut)
        
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }
    
    // MARK: - Motion Tracking
    
    private func startMotionTracking() {
        guard motionManager.isDeviceMotionAvailable else { return }
        
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] motion, _ in
            guard let motion = motion else { return }
            
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                if self.referenceAttitude == nil {
                    self.referenceAttitude = motion.attitude.copy() as? CMAttitude
                }
                
                if let reference = self.referenceAttitude {
                    let attitude = motion.attitude
                    attitude.multiply(byInverseOf: reference)
                    
                    let pitchOffset = Float(attitude.pitch) * 0.1
                    let yawOffset = Float(attitude.yaw) * 0.1
                    
                    self.deviceMotionOffset = SIMD3<Float>(yawOffset, pitchOffset, 0)
                }
            }
        }
    }
    
    // MARK: - Velocity Control
    
    func setVelocity(_ v: Float) {
        let clampedVelocity = min(max(v, 0), 0.99)
        velocity = clampedVelocity
        
        if state == .ready && velocity > 0.01 {
            state = .traveling
            travelStartTime = Date()
            showNarrativeStep(0)
        }
        
        updateEnvironmentEffects()
        
        if velocity > 0.7 && narrativeStep < 1 {
            showNarrativeStep(1)
        }
    }
    
    private func updateEnvironmentEffects() {
        let v = velocity
        let gamma = 1.0 / sqrt(1.0 - v * v)
        displayGamma = gamma
        contractionFactor = 1.0 / gamma
        
        // Subtle length contraction on rocket clock
        let clockCompression = 1.0 - v * 0.1
        rocketClockEntity?.scale = SIMD3<Float>(Float(clockCompression), 1, 1)
        
        // Subtle starfield compression - no color changes
        for star in starfieldEntities {
            // Gentle compression toward forward direction
            star.scale = SIMD3<Float>(1, 1, 1.0 - v * 0.8)
        }
    }
    
    // MARK: - Narrative System
    
    private func showNarrativeStep(_ step: Int) {
        guard step > narrativeStep else { return }
        narrativeStep = step
        
        switch step {
        case 0:
            // Brief, calm narrative
            learningText = "Moving away from Earth…"
            withAnimation(.easeIn(duration: 1.2)) {
                showLearning = true
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2.5))
                withAnimation(.easeOut(duration: 1.0)) {
                    self.showLearning = false
                }
            }
            
        case 1:
            // Only show return prompt, no text
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                self.showReturnPrompt = true
            }
            
        default:
            break
        }
    }
    
    // MARK: - Return / Twin Paradox
    
    func returnToEarth() {
        state = .returning
        showReturnPrompt = false
        animateVelocityReduction()
    }
    
    private func animateVelocityReduction() {
        velocity = max(0, velocity - 0.02)
        updateEnvironmentEffects()
        
        if velocity <= 0.01 {
            velocity = 0
            showTwinParadox()
        } else {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(30))
                self.animateVelocityReduction()
            }
        }
    }
    
    private func showTwinParadox() {
        guard !hasShownTwinParadox else { return }
        hasShownTwinParadox = true
        state = .complete
        
        // Bring clocks side by side
        earthClockEntity?.position = SIMD3<Float>(-0.06, 0, 0)
        rocketClockEntity?.position = SIMD3<Float>(0.06, 0, 0)
        
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(800))
            
            // Simple, calm message
            self.learningText = "You experienced less time."
            withAnimation(.easeIn(duration: 1.5)) {
                self.showLearning = true
            }
            
            try? await Task.sleep(for: .seconds(4))
            withAnimation(.easeOut(duration: 1.2)) {
                self.showLearning = false
            }
            
            try? await Task.sleep(for: .seconds(2))
            
            // Brief reality check
            self.learningText = "Motion changes your path through time."
            withAnimation(.easeIn(duration: 1.2)) {
                self.showLearning = true
            }
            
            try? await Task.sleep(for: .seconds(4))
            withAnimation(.easeOut(duration: 1.5)) {
                self.showLearning = false
            }
        }
    }
    
    // MARK: - Animation Loop
    
    private func startAnimationLoop() {
        displayLink = CADisplayLink(target: self, selector: #selector(updateAnimation))
        displayLink?.add(to: .main, forMode: .common)
        lastUpdateTime = CACurrentMediaTime()
    }
    
    @objc private func updateAnimation(_ displayLink: CADisplayLink) {
        let currentTime = CACurrentMediaTime()
        let dt = Float(currentTime - lastUpdateTime)
        lastUpdateTime = currentTime
        
        guard state == .traveling || state == .ready || state == .returning || state == .complete else { return }
        
        let v = velocity
        let gamma = 1.0 / sqrt(1.0 - v * v)
        let dilationFactor = Double(1.0 / gamma)
        
        earthTime += Double(dt)
        rocketTime += Double(dt) * dilationFactor
        
        if state == .traveling {
            travelDuration += dt
        }
        
        // Calculate clock hand angles based on elapsed time (one full rotation every 30 seconds)
        let earthAngle = Float(earthTime) * Float.pi / 15
        let rocketAngle = Float(rocketTime) * Float.pi / 15
        
        // Rotate pivot entities around Y-axis (vertical axis, clock face is in XZ plane)
        earthHandEntity?.orientation = simd_quatf(angle: -earthAngle, axis: SIMD3<Float>(0, 1, 0))
        rocketHandEntity?.orientation = simd_quatf(angle: -rocketAngle, axis: SIMD3<Float>(0, 1, 0))
        
        // Update rocket flame based on velocity (grows bigger and redder)
        
        if let flame = flameEntity as? ModelEntity {
            
            let baseY: Float = -0.06
            let offset = v * 0.018  // small movement
            
            let flameScale = 1.0 + v * 1.5 // Grows with velocity
            flame.position = SIMD3<Float>(0, baseY - offset, 0)
            flame.scale = SIMD3<Float>(flameScale, flameScale, flameScale)
            
            // Color: orange → red as velocity increases
            var flameMaterial = SimpleMaterial()
            let redAmount = 1.0
            let greenAmount = max(0.5 - v * 0.5, 0)
            let blueAmount = max(0.2 - v * 0.2, 0)
            flameMaterial.color = .init(tint: UIColor(red: CGFloat(redAmount), green: CGFloat(greenAmount), blue: CGFloat(blueAmount), alpha: 1.0))
            flameMaterial.metallic = .float(0.0)
            flameMaterial.roughness = .float(1.0)
            flame.model?.materials = [flameMaterial]
        }
        
        // Starfield moves only in rocket perspective
        if perspective == .rocket && v > 0.01 {
            for star in starfieldEntities {
                star.position.z += v * dt * 0.3
                if star.position.z > 0.5 {
                    star.position.z = -2.0
                }
            }
        }
        
        if state == .traveling,
           let startTime = travelStartTime,
           Date().timeIntervalSince(startTime) > 10,
           !showReturnPrompt,
           timeDifference > 1.0 {
            showReturnPrompt = true
        }
    }
    
    // MARK: - Reset
    
    func reset() {
        velocity = 0
        earthTime = 0
        rocketTime = 0
        travelDuration = 0
        displayGamma = 1.0
        contractionFactor = 1.0
        state = .ready
        travelStartTime = nil
        hasShownTwinParadox = false
        narrativeStep = 0
        showReturnPrompt = false
        showLearning = false
        perspective = .earth
        
        earthClockEntity?.position = SIMD3<Float>(0, 0.15, 0)
        rocketClockEntity?.position = SIMD3<Float>(0, 0.18, 0)
        rocketClockEntity?.scale = SIMD3<Float>(repeating: 1)
        
        // Reset flame to original state
        if let flame = flameEntity as? ModelEntity {
            flame.scale = SIMD3<Float>(repeating: 1)
            var flameMaterial = SimpleMaterial()
            flameMaterial.color = .init(tint: UIColor.orange)
            flame.model?.materials = [flameMaterial]
        }
        
        // Reset star colors and scales
        for star in starfieldEntities {
            star.scale = SIMD3<Float>(repeating: 1)
            if let model = star as? ModelEntity {
                var material = SimpleMaterial()
                material.color = .init(tint: UIColor.white.withAlphaComponent(0.4))
                model.model?.materials = [material]
            }
        }
        
        instructionText = "Timeline reset"
        withAnimation {
            showInstruction = true
        }
        
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            withAnimation {
                self.showInstruction = false
            }
        }
        
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
    
    // MARK: - Gestures
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        if state == .complete {
            reset()
        }
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            reset()
        }
    }
    
    // MARK: - Computed Properties
    
    var timeDifference: Double {
        return earthTime - rocketTime
    }
    
    var gammaFactor: Float {
        return 1.0 / sqrt(1.0 - velocity * velocity)
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        displayLink?.invalidate()
        displayLink = nil
        motionManager.stopDeviceMotionUpdates()
        arView?.session.pause()
    }
}

// MARK: - AR Session Delegate

extension TimeDilationARCoordinator: ARSessionDelegate {
    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Track device world position if needed
    }
}
