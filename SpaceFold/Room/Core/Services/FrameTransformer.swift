import Foundation
import Combine

/// Transforms events between reference frames
@MainActor
final class FrameTransformer: ObservableObject {
    
    @Published var observers: [Observer] = []
    @Published var events: [RelativeEvent] = []
    @Published var currentObserver: Observer?
    
    init() {
        // Setup default scenario: train and platform
        observers = [.stationary, .moving]
        currentObserver = observers.first
    }
    
    /// Add an observer
    func addObserver(_ observer: Observer) {
        observers.append(observer)
    }
    
    /// Add an event
    func addEvent(_ event: RelativeEvent) {
        events.append(event)
    }
    
    /// Switch to a different observer
    func switchObserver(to observer: Observer) {
        currentObserver = observer
    }
    
    /// Get events sorted by time for current observer
    var sortedEvents: [RelativeEvent] {
        guard let observer = currentObserver else { return events }
        return events.sortedByTime(for: observer)
    }
    
    /// Check if events are simultaneous for current observer
    func areSimultaneous(_ event1: RelativeEvent, _ event2: RelativeEvent) -> Bool {
        guard let observer = currentObserver else { return false }
        return events.areSimultaneous(event1, event2, for: observer)
    }
    
    /// Get time difference between events for current observer
    func timeDifference(between event1: RelativeEvent, and event2: RelativeEvent) -> Double? {
        guard let observer = currentObserver else { return nil }
        let t1 = event1.timeForObserver(observer)
        let t2 = event2.timeForObserver(observer)
        return t2 - t1
    }
    
    /// Setup train-platform scenario
    func setupTrainScenario() {
        observers = [
            Observer(name: "Platform", position: .zero, velocity: 0, isPrimary: true),
            Observer(name: "Train", position: .zero, velocity: 0.6)
        ]
        
        events = [
            RelativeEvent(name: "Flash A (Front)", position: SIMD3<Float>(1, 0, 0), labTime: 0.5, colorHue: 0.0),
            RelativeEvent(name: "Flash B (Back)", position: SIMD3<Float>(-1, 0, 0), labTime: 0.5, colorHue: 0.6)
        ]
        
        currentObserver = observers.first
    }
    
    /// Reset all
    func reset() {
        observers = []
        events = []
        currentObserver = nil
    }
}
