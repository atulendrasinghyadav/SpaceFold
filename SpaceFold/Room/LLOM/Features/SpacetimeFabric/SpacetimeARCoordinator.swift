import SwiftUI
import ARKit
import RealityKit
import Combine

/// Manages AR session state and entity lifecycle for Spacetime Fabric experience
@MainActor
final class SpacetimeARCoordinator: NSObject, ObservableObject {
    
    // MARK: - State
    
    enum ARState: Equatable, Sendable {
        case scanning
        case planeDetected
        case gridPlaced
        case interactive
    }
    
    enum GridStyle: String, CaseIterable, Sendable {
        case dots = "Curved Space"
        case lines = "Assumed Space"
    }
    
    @Published var state: ARState = .scanning
    @Published var instructionText: String = "Place spacetime on a surface"
    @Published var showLearningPrompt: Bool = false
    @Published var learningText: String = ""
    @Published var gridStyle: GridStyle = .dots
    @Published var spaceMode: Bool = false
    
    // MARK: - AR Entities
    
    weak var arView: ARView?
    private var gridAnchor: AnchorEntity?
    private var gridEntity: Entity?
    private var ghostGridEntity: Entity?
    private var massEntities: [UUID: ModelEntity] = [:]
    private var particleEntities: [Entity] = []
    
    // MARK: - Physics
    
    private let physicsEngine = PhysicsEngine()
    private var gridPoints: [[SIMD3<Float>]] = []
    private var gridLineEntities: [[ModelEntity]] = []
    
    // MARK: - Timing
    
    private var interactionStartTime: Date?
    private var displayLink: CADisplayLink?
    private var breathingPhase: Float = 0
    
    // MARK: - Constants
    
    private let gridSize: Float = 0.8
    private let gridResolution: Int = 20
    private let massRadius: Float = 0.05
    
    // MARK: - Setup
    
    func setupAR(_ arView: ARView) {
        self.arView = arView
        
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .automatic
        arView.session.run(config)
        arView.session.delegate = self
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        arView.addGestureRecognizer(panGesture)
        
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        arView.addGestureRecognizer(pinchGesture)
        
        startBreathingAnimation()
    }
    
    // MARK: - Visualization Controls
    
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
    
    /// Rebuild the grid with current style
    func rebuildGrid() {
        guard let anchor = gridAnchor, state == .gridPlaced || state == .interactive else { return }
        
        // Remove existing grid
        gridEntity?.removeFromParent()
        gridEntity = nil
        
        // Recreate with current style
        let grid = createGridEntity(opacity: 0.8, isGhost: false)
        anchor.addChild(grid)
        gridEntity = grid
        
        // Restore mass entities to new anchor
        for (_, massEntity) in massEntities {
            massEntity.removeFromParent()
            anchor.addChild(massEntity)
        }
        
        updateGridDeformation()
        
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }

    // MARK: - Grid Creation
    
    private func createGhostGrid(at position: SIMD3<Float>, on planeAnchor: ARPlaneAnchor) {
        guard let arView = arView else { return }
        
        ghostGridEntity?.removeFromParent()
        
        let anchor = AnchorEntity(world: position)
        
        let ghostGrid = createGridEntity(opacity: 0.8, isGhost: true)
        anchor.addChild(ghostGrid)
        
        arView.scene.addAnchor(anchor)
        ghostGridEntity = ghostGrid
        gridAnchor = anchor
        
        state = .planeDetected
        instructionText = "Tap to place spacetime"
    }
    
    private func placeGrid() {
        guard state == .planeDetected, let anchor = gridAnchor else { return }
        
        ghostGridEntity?.removeFromParent()
        ghostGridEntity = nil
        
        let grid = createGridEntity(opacity: 1, isGhost: false)
        anchor.addChild(grid)
        gridEntity = grid
        
        createMassIndicator()
        
        state = .gridPlaced
        instructionText = "Drag the mass onto spacetime"
        
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }
    
    private func createGridEntity(opacity: Float, isGhost: Bool) -> Entity {
        let parent = Entity()
        
        let step = gridSize / Float(gridResolution - 1)
        let offset = gridSize / 2
        
        gridPoints = []
        gridLineEntities = []
        
        // Create grid points (dots) - always created for deformation tracking
        for i in 0..<gridResolution {
            var row: [SIMD3<Float>] = []
            var lineRow: [ModelEntity] = []
            
            for j in 0..<gridResolution {
                let x = Float(j) * step - offset
                let z = Float(i) * step - offset
                row.append(SIMD3<Float>(x, 0, z))
                
                // Create visible dot if in dots mode
                if gridStyle == .dots || isGhost {
                    let pointMesh = MeshResource.generateSphere(radius: 0.004)
                    var material = SimpleMaterial()
                    material.color = .init(tint: .darkGray.withAlphaComponent(CGFloat(opacity * 0.9)))
                    material.metallic = .float(0.6)
                    material.roughness = .float(0.2)
                    
                    let pointEntity = ModelEntity(mesh: pointMesh, materials: [material])
                    pointEntity.position = SIMD3<Float>(x, 0, z)
                    parent.addChild(pointEntity)
                    lineRow.append(pointEntity)
                } else {
                    // Create invisible tracking entity for line mode
                    let pointEntity = ModelEntity()
                    pointEntity.position = SIMD3<Float>(x, 0, z)
                    lineRow.append(pointEntity)
                }
            }
            
            gridPoints.append(row)
            gridLineEntities.append(lineRow)
        }
        
        // Create grid lines only if in lines mode
        if gridStyle == .lines && !isGhost {
            createGridLines(parent: parent, opacity: opacity)
        }
        
        return parent
    }
    
    private func createGridLines(parent: Entity, opacity: Float) {
        let step = gridSize / Float(gridResolution - 1)
        let offset = gridSize / 2
        
        var material = SimpleMaterial()
        material.color = .init(tint: .cyan.withAlphaComponent(CGFloat(opacity * 0.6)))
        material.metallic = .float(0.3)
        material.roughness = .float(0.5)
        
        for i in 0..<gridResolution {
            let z = Float(i) * step - offset
            let lineMesh = MeshResource.generateBox(width: gridSize, height: 0.001, depth: 0.002)
            let lineEntity = ModelEntity(mesh: lineMesh, materials: [material])
            lineEntity.position = SIMD3<Float>(0, 0, z)
            parent.addChild(lineEntity)
        }
        
        for j in 0..<gridResolution {
            let x = Float(j) * step - offset
            let lineMesh = MeshResource.generateBox(width: 0.002, height: 0.001, depth: gridSize)
            let lineEntity = ModelEntity(mesh: lineMesh, materials: [material])
            lineEntity.position = SIMD3<Float>(x, 0, 0)
            parent.addChild(lineEntity)
        }
    }
    
    // MARK: - Mass Management
    
    private var massIndicatorEntity: ModelEntity?
    private var selectedMassID: UUID?
    
    private func createMassIndicator() {
        guard let anchor = gridAnchor else { return }
        
        let mesh = MeshResource.generateSphere(radius: massRadius)
        var material = SimpleMaterial()
        material.color = .init(tint: .purple.withAlphaComponent(0.9))
        material.metallic = .float(0.8)
        material.roughness = .float(0.2)
        
        let massEntity = ModelEntity(mesh: mesh, materials: [material])
        massEntity.position = SIMD3<Float>(gridSize / 2 + 0.15, 0.1, 0)
        
        let glowMesh = MeshResource.generateSphere(radius: massRadius * 1.3)
        var glowMaterial = SimpleMaterial()
        glowMaterial.color = .init(tint: .purple.withAlphaComponent(0.2))
        let glowEntity = ModelEntity(mesh: glowMesh, materials: [glowMaterial])
        massEntity.addChild(glowEntity)
        
        anchor.addChild(massEntity)
        massIndicatorEntity = massEntity
        
        let mass = MassObject(name: "Mass 1", position: massEntity.position, mass: 2.0)
        physicsEngine.addMass(mass)
        massEntities[mass.id] = massEntity
        selectedMassID = mass.id
    }
    
    func updateMassPosition(_ worldPosition: SIMD3<Float>) {
        guard let anchor = gridAnchor,
              let massID = selectedMassID,
              let massEntity = massEntities[massID] else { return }
        
        let localPosition = anchor.convert(position: worldPosition, from: nil)
        
        let clampedPosition = SIMD3<Float>(
            min(max(localPosition.x, -gridSize / 2), gridSize / 2),
            max(localPosition.y, 0),
            min(max(localPosition.z, -gridSize / 2), gridSize / 2)
        )
        
        massEntity.position = clampedPosition
        physicsEngine.updateMassPosition(id: massID, position: clampedPosition)
        
        updateGridDeformation()
        
        if interactionStartTime == nil && state == .gridPlaced {
            interactionStartTime = Date()
            state = .interactive
            instructionText = ""
        }
    }
    
    func updateMassScale(_ scale: Float) {
        guard let massID = selectedMassID,
              let massEntity = massEntities[massID] else { return }
        
        let newMass = max(0.5, min(10.0, Float(physicsEngine.masses.first?.mass ?? 2.0) * scale))
        let newRadius = massRadius * (0.5 + newMass * 0.15)
        
        massEntity.scale = SIMD3<Float>(repeating: newRadius / massRadius)
        physicsEngine.updateMassStrength(id: massID, mass: newMass)
        updateGridDeformation()
    }
    
    // MARK: - Grid Deformation
    
    private func updateGridDeformation() {
        guard !gridLineEntities.isEmpty else { return }
        
        let step = gridSize / Float(gridResolution - 1)
        let offset = gridSize / 2
        
        for i in 0..<gridResolution {
            for j in 0..<gridResolution {
                let x = Float(j) * step - offset
                let z = Float(i) * step - offset
                
                var yOffset: Float = 0
                
                for mass in physicsEngine.masses {
                    let dx = x - mass.position.x
                    let dz = z - mass.position.z
                    let distance = sqrt(dx * dx + dz * dz)
                    
                    let sigma: Float = 0.15 * (1 + mass.mass * 0.1)
                    let deformation = -mass.mass * 0.03 * exp(-distance * distance / (2 * sigma * sigma))
                    yOffset += deformation
                }
                
                yOffset += sin(breathingPhase) * 0.002
                
                if i < gridLineEntities.count && j < gridLineEntities[i].count {
                    gridLineEntities[i][j].position = SIMD3<Float>(x, yOffset, z)
                }
            }
        }
    }
    
    // MARK: - Particle Release
    
    func releaseParticle(from position: SIMD3<Float>? = nil) {
        guard let anchor = gridAnchor else { return }
        guard let mass = physicsEngine.masses.first else {
            // No mass - just shoot straight
            let startPos = SIMD3<Float>(-gridSize / 2, 0.01, 0)
            let path = [startPos, SIMD3<Float>(gridSize / 2, 0.01, 0)]
            createAndAnimateParticle(at: startPos, path: path, anchor: anchor)
            return
        }
        
        // Mass-dependent behavior:
        // Low mass (< 2): Light deflects past mass (gravitational lensing)
        // Medium mass (2-5): Light orbits a few times then escapes or falls in
        // High mass (> 5): Light spirals in tightly
        
        var velocity: SIMD3<Float>
        let stepCount: Int
        var startPos: SIMD3<Float>
        
        if mass.mass < 2.0 {
            // LOW MASS: Gravitational lensing - light bends past the mass
            // Start further away for visible deflection arc
            let offsetDistance: Float = 0.25 + (0.15 / max(mass.mass, 0.5))
            startPos = position ?? SIMD3<Float>(
                mass.position.x - offsetDistance,
                0.01,
                mass.position.z + Float.random(in: 0.03...0.08) // Offset perpendicular to create fly-by
            )
            
            // Use deflection velocity - particle flies PAST the mass, not into it
            velocity = physicsEngine.calculateDeflectionVelocity(
                from: startPos,
                past: mass,
                impactParameter: 0.08
            )
            stepCount = 500
        } else if mass.mass < 5.0 {
            // MEDIUM MASS: Orbits then falls in
            let offsetDistance: Float = 0.15 + (0.1 / max(mass.mass, 0.5))
            startPos = position ?? SIMD3<Float>(
                mass.position.x - offsetDistance,
                0.01,
                mass.position.z + Float.random(in: -0.02...0.02)
            )
            velocity = physicsEngine.calculateOrbitalVelocity(
                from: startPos,
                around: mass,
                orbitFactor: 0.85 // Spirals inward moderately
            )
            stepCount = 600
        } else {
            // HIGH MASS: Tight spiral directly into center
            let offsetDistance: Float = 0.15 + (0.1 / max(mass.mass, 0.5))
            startPos = position ?? SIMD3<Float>(
                mass.position.x - offsetDistance,
                0.01,
                mass.position.z + Float.random(in: -0.02...0.02)
            )
            velocity = physicsEngine.calculateOrbitalVelocity(
                from: startPos,
                around: mass,
                orbitFactor: 0.7 // Spirals inward quickly
            )
            stepCount = 800
        }
        
        let path = physicsEngine.calculateGeodesic(from: startPos, velocity: velocity, steps: stepCount)
        createAndAnimateParticle(at: startPos, path: path, anchor: anchor)
        
        // Learning prompt
        if !showLearningPrompt {
            let message = mass.mass < 2.0
                ? "Light bends around mass but escapes"
                : "Massive objects trap light in orbits"
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(3))
                self?.showLearningPrompt = true
                self?.learningText = message
            }
        }
    }
    
    private func createAndAnimateParticle(at startPos: SIMD3<Float>, path: [SIMD3<Float>], anchor: AnchorEntity) {
        let particleMesh = MeshResource.generateSphere(radius: 0.01)
        var material = SimpleMaterial()
        material.color = .init(tint: .yellow)
        material.metallic = .float(1.0)
        material.roughness = .float(0.0)
        
        let particle = ModelEntity(mesh: particleMesh, materials: [material])
        particle.position = startPos
        
        // Glow effect
        let glowMesh = MeshResource.generateSphere(radius: 0.016)
        var glowMaterial = SimpleMaterial()
        glowMaterial.color = .init(tint: .orange.withAlphaComponent(0.35))
        let glowEntity = ModelEntity(mesh: glowMesh, materials: [glowMaterial])
        particle.addChild(glowEntity)
        
        anchor.addChild(particle)
        particleEntities.append(particle)
        
        animateParticle(particle, along: path, index: 0)
        
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
    
    private func animateParticle(_ particle: ModelEntity, along path: [SIMD3<Float>], index: Int) {
        guard index < path.count else {
            particle.removeFromParent()
            particleEntities.removeAll { $0 === particle }
            return
        }
        
        particle.position = path[index]
        
        // Faster frame rate for smooth orbital motion using Task
        Task { @MainActor [weak self, weak particle] in
            try? await Task.sleep(for: .milliseconds(16))
            guard let particle = particle else { return }
            self?.animateParticle(particle, along: path, index: index + 1)
        }
    }
    
    // MARK: - Breathing Animation
    
    private func startBreathingAnimation() {
        displayLink = CADisplayLink(target: self, selector: #selector(updateBreathing))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    @objc private func updateBreathing() {
        breathingPhase += 0.02
        if state == .interactive || state == .gridPlaced {
            updateGridDeformation()
        }
        
        if let startTime = interactionStartTime,
           Date().timeIntervalSince(startTime) > 25,
           !showLearningPrompt {
            learningText = "Try moving the mass — does the path change?"
            showLearningPrompt = true
        }
    }
    
    // MARK: - Gesture Handlers
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let arView = arView else { return }
        
        let location = gesture.location(in: arView)
        
        switch state {
        case .planeDetected:
            placeGrid()
            
        case .interactive, .gridPlaced:
            let hits = arView.hitTest(location)
            if hits.isEmpty {
                releaseParticle()
            }
            
        default:
            break
        }
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let arView = arView, state == .gridPlaced || state == .interactive else { return }
        
        let location = gesture.location(in: arView)
        
        let results = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .horizontal)
        
        if let result = results.first {
            let worldPosition = SIMD3<Float>(
                result.worldTransform.columns.3.x,
                result.worldTransform.columns.3.y,
                result.worldTransform.columns.3.z
            )
            updateMassPosition(worldPosition)
        }
        
        if gesture.state == .ended {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        }
    }
    
    private var initialPinchScale: Float = 1.0
    
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .began:
            initialPinchScale = 1.0
        case .changed:
            let scale = Float(gesture.scale)
            updateMassScale(scale / initialPinchScale)
            initialPinchScale = scale
        default:
            break
        }
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        displayLink?.invalidate()
        displayLink = nil
        arView?.session.pause()
    }
}

// MARK: - ARSessionDelegate

extension SpacetimeARCoordinator: ARSessionDelegate {
    nonisolated func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        Task { @MainActor in
            for anchor in anchors {
                if let planeAnchor = anchor as? ARPlaneAnchor,
                   planeAnchor.alignment == .horizontal,
                   state == .scanning {
                    createGhostGrid(at: simd_make_float3(planeAnchor.transform.columns.3), on: planeAnchor)
                    break
                }
            }
        }
    }
    
    nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        // Update ghost grid position if needed
    }
}
