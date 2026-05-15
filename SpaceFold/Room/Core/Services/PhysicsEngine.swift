import Foundation
import simd
import Combine

/// Physics engine for spacetime curvature and path calculation
@MainActor
final class PhysicsEngine: ObservableObject {
    
    @Published var masses: [MassObject] = []
    @Published var grid: SpacetimeGrid
    
    init() {
        self.grid = SpacetimeGrid()
    }
    
    /// Add a mass to the simulation
    func addMass(_ mass: MassObject) {
        masses.append(mass)
        updateGrid()
    }
    
    /// Remove a mass from simulation
    func removeMass(_ mass: MassObject) {
        masses.removeAll { $0.id == mass.id }
        updateGrid()
    }
    
    /// Update mass position
    func updateMassPosition(id: UUID, position: SIMD3<Float>) {
        if let index = masses.firstIndex(where: { $0.id == id }) {
            masses[index].position = position
            updateGrid()
        }
    }
    
    /// Update mass strength
    func updateMassStrength(id: UUID, mass: Float) {
        if let index = masses.firstIndex(where: { $0.id == id }) {
            masses[index].mass = mass
            masses[index].radius = 0.1 + (mass * 0.05)
            updateGrid()
        }
    }
    
    /// Recalculate grid deformation
    private func updateGrid() {
        grid.reset()
        for mass in masses {
            grid.applyDeformation(massPosition: mass.position, massStrength: mass.mass)
        }
    }
    
    /// Calculate geodesic path - creates visible curved orbit around mass
    func calculateGeodesic(from start: SIMD3<Float>, velocity: SIMD3<Float>, steps: Int = 100) -> [SIMD3<Float>] {
        var path: [SIMD3<Float>] = [start]
        var position = start
        var vel = velocity
        let dt: Float = 0.008 // Small time step for smooth curves
        
        for _ in 0..<steps {
            // RK4 integration
            let (k1v, k1a) = derivatives(position: position, velocity: vel)
            let (k2v, k2a) = derivatives(position: position + k1v * dt * 0.5, velocity: vel + k1a * dt * 0.5)
            let (k3v, k3a) = derivatives(position: position + k2v * dt * 0.5, velocity: vel + k2a * dt * 0.5)
            let (k4v, k4a) = derivatives(position: position + k3v * dt, velocity: vel + k3a * dt)
            
            position += (k1v + 2 * k2v + 2 * k3v + k4v) * (dt / 6)
            vel += (k1a + 2 * k2a + 2 * k3a + k4a) * (dt / 6)
            
            // Check absorption by mass - reduced radius for deflection to work
            for mass in masses {
                if simd_length(position - mass.position) < 0.012 {
                    path.append(mass.position)
                    return path
                }
            }
            
            // Stay within bounds
            if simd_length(position) > 1.5 { break }
            
            path.append(position)
        }
        
        return path
    }
    
    /// Calculate velocity for a stable circular orbit around the mass
    /// The particle will revolve around the mass in visible circles
    func calculateOrbitalVelocity(from startPosition: SIMD3<Float>, around targetMass: MassObject, orbitFactor: Float = 1.0) -> SIMD3<Float> {
        let direction = targetMass.position - startPosition
        let distance = simd_length(direction)
        
        guard distance > 0.01 else { return SIMD3<Float>(0.1, 0, 0) }
        
        // For circular orbit: v = sqrt(GM/r)
        // Using higher GM for more visible gravitational effect
        let GM: Float = targetMass.mass * 0.12
        let circularSpeed = sqrt(GM / distance)
        
        // Apply orbit factor (1.0 = circular, <1.0 = spirals in, >1.0 = spirals out)
        let orbitalSpeed = circularSpeed * orbitFactor
        
        // Tangential direction (perpendicular to radial, in XZ plane)
        let radialDir = simd_normalize(direction)
        let tangent = SIMD3<Float>(-radialDir.z, 0, radialDir.x) // 90° rotation in XZ plane
        
        return tangent * orbitalSpeed
    }
    
    /// Calculate velocity for gravitational deflection (light bending past mass)
    /// Particle travels PAST the mass with path curved by gravity
    func calculateDeflectionVelocity(from startPosition: SIMD3<Float>, past targetMass: MassObject, impactParameter: Float = 0.08) -> SIMD3<Float> {
        let direction = targetMass.position - startPosition
        let distance = simd_length(direction)
        
        guard distance > 0.01 else { return SIMD3<Float>(0.3, 0, 0) }
        
        // Calculate velocity perpendicular to mass direction (fly-by trajectory)
        let radialDir = simd_normalize(direction)
        
        // Primary direction: perpendicular to mass (will pass by it)
        // Add slight inward component for visible curve
        let tangent = SIMD3<Float>(-radialDir.z, 0, radialDir.x)
        
        // Higher velocity = weaker deflection (light-like behavior)
        // Calculate based on mass - lower mass = faster escape
        let baseSpeed: Float = 0.25 + (2.0 / max(targetMass.mass, 0.5))
        
        // Add small radial component toward mass for visible curve
        let radialComponent = radialDir * 0.02
        
        return (tangent * baseSpeed) + radialComponent
    }
    
    /// Compute derivatives for orbital motion
    private func derivatives(position: SIMD3<Float>, velocity: SIMD3<Float>) -> (SIMD3<Float>, SIMD3<Float>) {
        var acceleration = SIMD3<Float>.zero
        
        for mass in masses {
            let direction = mass.position - position
            let distance = simd_length(direction)
            
            guard distance > 0.02 else { continue }
            
            // Strong gravitational pull for visible orbits
            // a = GM/r² toward mass
            let GM: Float = mass.mass * 0.12
            let force = GM / (distance * distance)
            acceleration += simd_normalize(direction) * force
        }
        
        return (velocity, acceleration)
    }
    
    /// Reset simulation
    func reset() {
        masses.removeAll()
        grid.reset()
    }
}
