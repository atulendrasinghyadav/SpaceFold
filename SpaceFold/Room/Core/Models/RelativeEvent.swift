import Foundation
import simd

/// Represents an event in spacetime with timestamps per observer
struct RelativeEvent: Identifiable, Sendable {
    let id = UUID()
    
    /// Event name/description
    var name: String
    
    /// Position where event occurs
    var position: SIMD3<Float>
    
    /// Time in the "lab" reference frame
    var labTime: Double
    
    /// Event color for visualization
    var colorHue: Float
    
    init(name: String, position: SIMD3<Float>, labTime: Double, colorHue: Float = 0.5) {
        self.name = name
        self.position = position
        self.labTime = labTime
        self.colorHue = colorHue
    }
    
    /// Calculate event time as seen by a moving observer (Lorentz transform)
    func timeForObserver(_ observer: Observer) -> Double {
        let v = Double(observer.velocity)
        let x = Double(position.x)
        let t = labTime
        
        // Lorentz transformation: t' = γ(t - vx/c²)
        // With c = 1 (natural units)
        let gamma = observer.gamma
        return gamma * (t - v * x)
    }
    
    /// Calculate position as seen by moving observer
    func positionForObserver(_ observer: Observer) -> SIMD3<Float> {
        let v = Double(observer.velocity)
        let gamma = observer.gamma
        let t = labTime
        
        // Length contraction along direction of motion
        let xPrime = gamma * (Double(position.x) - v * t)
        
        return SIMD3<Float>(Float(xPrime), position.y, position.z)
    }
}

// MARK: - Event Ordering

extension Array where Element == RelativeEvent {
    /// Check if two events are simultaneous for an observer
    func areSimultaneous(_ event1: RelativeEvent, _ event2: RelativeEvent, for observer: Observer, tolerance: Double = 0.01) -> Bool {
        let t1 = event1.timeForObserver(observer)
        let t2 = event2.timeForObserver(observer)
        return abs(t1 - t2) < tolerance
    }
    
    /// Sort events by time for a specific observer
    func sortedByTime(for observer: Observer) -> [RelativeEvent] {
        return self.sorted { $0.timeForObserver(observer) < $1.timeForObserver(observer) }
    }
}
