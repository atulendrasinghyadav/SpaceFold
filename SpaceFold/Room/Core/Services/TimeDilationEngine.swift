import Foundation
import Combine

/// Engine for time dilation visualization
@MainActor
final class TimeDilationEngine: ObservableObject {
    
    /// Velocity as fraction of light speed (0 to <1)
    @Published var velocity: Double = 0.0 {
        didSet {
            velocity = min(velocity, 0.999)
            updateDilation()
        }
    }
    
    /// Stationary clock time
    @Published var stationaryTime: Double = 0.0
    
    /// Moving clock time (dilated)
    @Published var movingTime: Double = 0.0
    
    /// Lorentz factor (gamma)
    @Published var gamma: Double = 1.0
    
    /// Time dilation factor
    @Published var dilationFactor: Double = 1.0
    
    /// Is simulation running
    @Published var isRunning: Bool = false
    
    private var timer: Timer?
    
    init() {}
    
    /// Start the time simulation
    func start() {
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }
    
    /// Pause the simulation
    func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    /// Reset clocks
    func reset() {
        pause()
        stationaryTime = 0
        movingTime = 0
        velocity = 0
    }
    
    /// Update dilation values
    private func updateDilation() {
        let v = velocity
        gamma = 1.0 / sqrt(1.0 - v * v)
        dilationFactor = 1.0 / gamma
    }
    
    /// Tick the clocks
    private func tick() {
        let dt = 0.1
        stationaryTime += dt
        movingTime += dt * dilationFactor
    }
    
    /// Format time for display
    func formatTime(_ time: Double) -> String {
        return String(format: "%.2f s", time)
    }
    
    /// Get time difference description
    var timeDifferenceDescription: String {
        let diff = stationaryTime - movingTime
        if diff < 0.01 {
            return "Clocks synchronized"
        }
        return String(format: "Moving clock is %.2fs behind", diff)
    }
}
