import Foundation
import simd

/// Represents a spacetime grid for visualization
struct SpacetimeGrid: Sendable {
    /// Grid dimensions
    let rows: Int
    let columns: Int
    
    /// Grid point positions (can be deformed)
    var points: [[SIMD3<Float>]]
    
    /// Original flat positions
    let originalPoints: [[SIMD3<Float>]]
    
    init(rows: Int = 20, columns: Int = 20, size: Float = 2.0) {
        self.rows = rows
        self.columns = columns
        
        var points: [[SIMD3<Float>]] = []
        let step = size / Float(max(rows - 1, 1))
        let offset = size / 2
        
        for i in 0..<rows {
            var row: [SIMD3<Float>] = []
            for j in 0..<columns {
                let x = Float(j) * step - offset
                let z = Float(i) * step - offset
                row.append(SIMD3<Float>(x, 0, z))
            }
            points.append(row)
        }
        
        self.points = points
        self.originalPoints = points
    }
    
    /// Reset grid to flat state
    mutating func reset() {
        points = originalPoints
    }
    
    /// Apply deformation based on mass position
    mutating func applyDeformation(massPosition: SIMD3<Float>, massStrength: Float) {
        for i in 0..<rows {
            for j in 0..<columns {
                let original = originalPoints[i][j]
                let distance = simd_distance(
                    SIMD2<Float>(original.x, original.z),
                    SIMD2<Float>(massPosition.x, massPosition.z)
                )
                
                // Inverse square deformation
                let deformation = massStrength / (distance * distance + 0.5)
                points[i][j].y = -deformation
            }
        }
    }
}
