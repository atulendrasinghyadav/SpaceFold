import Foundation
import simd

/// Represents an observer in a reference frame
struct Observer: Identifiable, Sendable {
    let id = UUID()
    
    /// Observer name
    var name: String
    
    /// Position in space
    var position: SIMD3<Float>
    
    /// Velocity as fraction of light speed (0 to <1)
    var velocity: Float
    
    /// Direction of motion (normalized)
    var direction: SIMD3<Float>
    
    /// Proper time (observer's own clock)
    var properTime: Double
    
    /// Is this the primary/user observer?
    var isPrimary: Bool
    
    init(name: String, position: SIMD3<Float> = .zero, velocity: Float = 0, direction: SIMD3<Float> = SIMD3<Float>(1, 0, 0), isPrimary: Bool = false) {
        self.name = name
        self.position = position
        self.velocity = min(velocity, 0.999) // Cap below light speed
        self.direction = simd_normalize(direction)
        self.properTime = 0
        self.isPrimary = isPrimary
    }
    
    /// Lorentz factor (gamma)
    var gamma: Double {
        let v = Double(velocity)
        return 1.0 / sqrt(1.0 - v * v)
    }
    
    /// Time dilation factor
    var timeDilation: Double {
        return 1.0 / gamma
    }
    
    /// Update proper time based on coordinate time
    mutating func updateProperTime(coordinateDelta: Double) {
        properTime += coordinateDelta * timeDilation
    }
}

// MARK: - Preset Observers

extension Observer {
    static let stationary = Observer(name: "Platform", position: .zero, velocity: 0, isPrimary: true)
    static let moving = Observer(name: "Train", position: SIMD3<Float>(0, 0, 0), velocity: 0.8, direction: SIMD3<Float>(1, 0, 0))
}
