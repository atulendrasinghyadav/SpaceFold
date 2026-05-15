import Foundation
import simd

/// Represents a mass object that curves spacetime
struct MassObject: Identifiable, Sendable {
    let id = UUID()
    
    /// Name of the mass (e.g., "Sun", "Earth")
    var name: String
    
    /// Position in 3D space
    var position: SIMD3<Float>
    
    /// Mass value (arbitrary units for visualization)
    var mass: Float
    
    /// Visual radius
    var radius: Float
    
    /// Color representation
    var colorHue: Float
    
    init(name: String = "Mass", position: SIMD3<Float> = .zero, mass: Float = 1.0) {
        self.name = name
        self.position = position
        self.mass = mass
        self.radius = 0.1 + (mass * 0.05)
        self.colorHue = Float.random(in: 0...1)
    }
    
    /// Gravitational influence at a point
    func influenceAt(point: SIMD3<Float>) -> Float {
        let distance = simd_distance(position, point)
        guard distance > 0.01 else { return mass * 100 }
        return mass / (distance * distance)
    }
}

// MARK: - Preset Masses

extension MassObject {
    static let sun = MassObject(name: "Sun", position: .zero, mass: 10.0)
    static let earth = MassObject(name: "Earth", position: SIMD3<Float>(0.5, 0, 0), mass: 1.0)
    static let moon = MassObject(name: "Moon", position: SIMD3<Float>(0.6, 0, 0), mass: 0.1)
}
