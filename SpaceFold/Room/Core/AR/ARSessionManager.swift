import Foundation
import ARKit
import RealityKit
import Combine

/// Manages ARKit session and plane detection
@MainActor
final class ARSessionManager: ObservableObject {
    
    @Published var isSessionReady: Bool = false
    @Published var planeDetected: Bool = false
    @Published var statusMessage: String = "Initializing AR..."
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {}
    
    /// Configure AR session for plane detection
    func configureSession() -> ARWorldTrackingConfiguration {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configuration.environmentTexturing = .automatic
        
        // Enable scene reconstruction if available
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
        }
        
        return configuration
    }
    
    /// Handle plane detection
    func onPlaneDetected() {
        planeDetected = true
        statusMessage = "Plane detected! Tap to place grid."
    }
    
    /// Update status
    func updateStatus(_ message: String) {
        statusMessage = message
    }
    
    /// Reset session state
    func reset() {
        isSessionReady = false
        planeDetected = false
        statusMessage = "Initializing AR..."
    }
}
