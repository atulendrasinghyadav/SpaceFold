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
    private var gridMeshEntity: ModelEntity?
    
    // MARK: - Timing
    
    private var interactionStartTime: Date?
    private var displayLink: CADisplayLink?
    private var breathingPhase: Float = 0
    private var frameCounter: Int = 0
    private var particleAnimationTasks: [Task<Void, Never>] = []
    
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
        
        cancelAllParticles()
        
        gridEntity?.removeFromParent()
        gridEntity = nil
        gridMeshEntity = nil
        
        let grid = createGridEntity(opacity: 0.8, isGhost: false)
        anchor.addChild(grid)
        gridEntity = grid
        
        for (_, massEntity) in massEntities {
            massEntity.removeFromParent()
            anchor.addChild(massEntity)
        }
        
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
        let shouldDeform = (gridStyle == .dots) && !isGhost
        
        guard let mesh = generateGridMesh(deformed: shouldDeform) else { return parent }
        
        var material = SimpleMaterial()
        if isGhost {
            material.color = .init(tint: .cyan.withAlphaComponent(CGFloat(opacity * 0.5)))
        } else if gridStyle == .dots {
            material.color = .init(tint: .cyan.withAlphaComponent(CGFloat(opacity * 0.9)))
        } else {
            material.color = .init(tint: .cyan.withAlphaComponent(CGFloat(opacity * 0.8)))
        }
        material.metallic = .float(0.4)
        material.roughness = .float(0.4)
        
        let gridModel = ModelEntity(mesh: mesh, materials: [material])
        parent.addChild(gridModel)
        
        if !isGhost {
            gridMeshEntity = gridModel
        }
        
        return parent
    }
    
    // MARK: - Procedural Grid Mesh
    
    /// Generates a single grid mesh as connected line-segments (thin quads).
    /// When `deformed` is true, mass-driven curvature is applied to vertex positions.
    private func generateGridMesh(deformed: Bool) -> MeshResource? {
        let step = gridSize / Float(gridResolution - 1)
        let offset = gridSize / 2
        
        // 1. Compute grid-point positions
        var points: [[SIMD3<Float>]] = []
        points.reserveCapacity(gridResolution)
        
        for i in 0..<gridResolution {
            var row: [SIMD3<Float>] = []
            row.reserveCapacity(gridResolution)
            for j in 0..<gridResolution {
                let x = Float(j) * step - offset
                let z = Float(i) * step - offset
                var y: Float = 0
                
                if deformed {
                    for mass in physicsEngine.masses {
                        let dx = x - mass.position.x
                        let dz = z - mass.position.z
                        let dist = sqrt(dx * dx + dz * dz)
                        let sigma: Float = 0.15 * (1 + mass.mass * 0.1)
                        y += -mass.mass * 0.03 * exp(-(dist * dist) / (2 * sigma * sigma))
                    }
                    y += sin(breathingPhase) * 0.002
                }
                
                row.append(SIMD3<Float>(x, y, z))
            }
            points.append(row)
        }
        
        // 2. Build triangle mesh from thin quad segments
        //    Each segment = 4 vertices + 2 triangles (6 indices)
        let segmentCount = gridResolution * (gridResolution - 1) * 2 // horizontal + vertical
        var positions: [SIMD3<Float>] = []
        var normals:   [SIMD3<Float>] = []
        var indices:   [UInt32] = []
        positions.reserveCapacity(segmentCount * 4)
        normals.reserveCapacity(segmentCount * 4)
        indices.reserveCapacity(segmentCount * 6)
        
        let halfW: Float = 0.002
        
        // Horizontal lines
        for i in 0..<gridResolution {
            for j in 0..<(gridResolution - 1) {
                appendSegmentQuad(from: points[i][j], to: points[i][j + 1],
                                  halfWidth: halfW, positions: &positions,
                                  normals: &normals, indices: &indices)
            }
        }
        
        // Vertical lines
        for j in 0..<gridResolution {
            for i in 0..<(gridResolution - 1) {
                appendSegmentQuad(from: points[i][j], to: points[i + 1][j],
                                  halfWidth: halfW, positions: &positions,
                                  normals: &normals, indices: &indices)
            }
        }
        
        guard !positions.isEmpty else { return nil }
        
        var descriptor = MeshDescriptor(name: "spacetimeGrid")
        descriptor.positions = MeshBuffer(positions)
        descriptor.normals   = MeshBuffer(normals)
        descriptor.primitives = .triangles(indices)
        
        return try? MeshResource.generate(from: [descriptor])
    }
    
    /// Appends a thin quad (two triangles) connecting two adjacent grid points.
    private func appendSegmentQuad(from p1: SIMD3<Float>, to p2: SIMD3<Float>,
                                   halfWidth: Float,
                                   positions: inout [SIMD3<Float>],
                                   normals:   inout [SIMD3<Float>],
                                   indices:   inout [UInt32]) {
        let dir = p2 - p1
        guard simd_length(dir) > 1e-5 else { return }
        
        let forward = simd_normalize(dir)
        let up = SIMD3<Float>(0, 1, 0)
        var side = simd_cross(forward, up)
        if simd_length(side) < 1e-5 { side = SIMD3<Float>(1, 0, 0) }
        side = simd_normalize(side) * halfWidth
        
        let normal = SIMD3<Float>(0, 1, 0)
        let base = UInt32(positions.count)
        
        positions.append(contentsOf: [p1 - side, p1 + side, p2 + side, p2 - side])
        normals.append(contentsOf:   [normal, normal, normal, normal])
        indices.append(contentsOf:   [base, base + 1, base + 2,
                                      base, base + 2, base + 3])
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
        massEntity.position = SIMD3<Float>(gridSize / 2 + 0.15, 0, 0)
        
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
            0,
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
    
    /// Regenerates the grid mesh with current mass-driven curvature.
    /// Only applies in "Curved Space" mode; no-op for "Assumed Space".
    private func updateGridDeformation() {
        guard gridStyle == .dots, let meshEntity = gridMeshEntity else { return }
        guard let newMesh = generateGridMesh(deformed: true) else { return }
        let materials = meshEntity.model?.materials ?? []
        meshEntity.model = ModelComponent(mesh: newMesh, materials: materials)
    }
    
    // MARK: - Particle Release
    
    func releaseParticle(from position: SIMD3<Float>? = nil) {
        guard let anchor = gridAnchor else { return }
        guard let mass = physicsEngine.masses.first else {
            // No mass - just shoot straight
            let startPos = SIMD3<Float>(-gridSize / 2, 0, 0)
            let path = [startPos, SIMD3<Float>(gridSize / 2, 0, 0)]
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
                0,
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
                0,
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
                0,
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
        let task = Task { @MainActor [weak self, weak particle] in
            for i in index..<path.count {
                guard !Task.isCancelled, let particle = particle else { return }
                particle.position = path[i]
                try? await Task.sleep(for: .milliseconds(16))
            }
            // Animation complete — remove particle from scene
            guard let self = self, let particle = particle else { return }
            particle.removeFromParent()
            self.particleEntities.removeAll { $0 === particle }
        }
        particleAnimationTasks.append(task)
    }
    
    // MARK: - Breathing Animation
    
    private func startBreathingAnimation() {
        displayLink = CADisplayLink(target: self, selector: #selector(updateBreathing))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    @objc private func updateBreathing() {
        breathingPhase += 0.02
        frameCounter += 1
        
        // Throttle breathing-driven mesh regeneration to every 3rd frame
        if (state == .interactive || state == .gridPlaced) && frameCounter % 3 == 0 {
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
    
    // MARK: - Particle Cleanup
    
    private func cancelAllParticles() {
        for task in particleAnimationTasks {
            task.cancel()
        }
        particleAnimationTasks.removeAll()
        for entity in particleEntities {
            entity.removeFromParent()
        }
        particleEntities.removeAll()
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        displayLink?.invalidate()
        displayLink = nil
        cancelAllParticles()
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
