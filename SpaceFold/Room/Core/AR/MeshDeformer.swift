import Foundation
import UIKit
import RealityKit
import simd

/// Creates and deforms mesh for spacetime visualization
@MainActor
final class MeshDeformer {
    
    /// Create a grid mesh entity
    static func createGridMesh(rows: Int = 20, columns: Int = 20, size: Float = 2.0) -> ModelEntity {
        // Create plane mesh
        let mesh = MeshResource.generatePlane(width: size, depth: size, cornerRadius: 0)
        
        // Create wireframe-style material
        var material = SimpleMaterial()
        material.color = .init(tint: .cyan.withAlphaComponent(0.8))
        material.metallic = .float(0.8)
        material.roughness = .float(0.2)
        
        let entity = ModelEntity(mesh: mesh, materials: [material])
        return entity
    }
    
    /// Create grid lines for visualization
    static func createGridLines(rows: Int = 20, columns: Int = 20, size: Float = 2.0) -> Entity {
        let parent = Entity()
        let step = size / Float(max(rows - 1, 1))
        let offset = size / 2
        
        // Material for lines
        var material = SimpleMaterial()
        material.color = .init(tint: .cyan.withAlphaComponent(0.6))
        
        // Create horizontal lines
        for i in 0..<rows {
            let z = Float(i) * step - offset
            let start = SIMD3<Float>(-offset, 0, z)
            let end = SIMD3<Float>(offset, 0, z)
            
            if let line = createLine(from: start, to: end, material: material) {
                parent.addChild(line)
            }
        }
        
        // Create vertical lines
        for j in 0..<columns {
            let x = Float(j) * step - offset
            let start = SIMD3<Float>(x, 0, -offset)
            let end = SIMD3<Float>(x, 0, offset)
            
            if let line = createLine(from: start, to: end, material: material) {
                parent.addChild(line)
            }
        }
        
        return parent
    }
    
    /// Create a line between two points
    private static func createLine(from start: SIMD3<Float>, to end: SIMD3<Float>, material: SimpleMaterial) -> ModelEntity? {
        let length = simd_distance(start, end)
        guard length > 0 else { return nil }
        
        let mesh = MeshResource.generateBox(width: 0.005, height: 0.002, depth: length)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        
        let midpoint = (start + end) / 2
        entity.position = midpoint
        
        // Rotate to align with direction
        let direction = simd_normalize(end - start)
        let rotation = simd_quatf(from: SIMD3<Float>(0, 0, 1), to: direction)
        entity.orientation = rotation
        
        return entity
    }
    
    /// Create a sphere for mass visualization
    static func createMassSphere(radius: Float, color: UIColor = .purple) -> ModelEntity {
        let mesh = MeshResource.generateSphere(radius: radius)
        var material = SimpleMaterial()
        material.color = .init(tint: color)
        material.metallic = .float(0.9)
        material.roughness = .float(0.1)
        
        return ModelEntity(mesh: mesh, materials: [material])
    }
}
