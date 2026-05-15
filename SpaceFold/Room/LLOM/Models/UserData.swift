import SwiftUI
import Combine

class UserData: ObservableObject {
    // Persist basic metrics using AppStorage where possible, 
    // but for ObservableObject we typically use @Published and sync with UserDefaults manually if complex.
    // For simplicity in this prototype, we'll use @Published and standard UserDefaults.
    
    @Published var timeWalkDuration: TimeInterval {
        didSet { UserDefaults.standard.set(timeWalkDuration, forKey: "timeWalkDuration") }
    }
    
    @Published var referenceFrameSwitches: Int {
        didSet { UserDefaults.standard.set(referenceFrameSwitches, forKey: "referenceFrameSwitches") }
    }
    
    // Tracking unique visited features
    @Published var visitedFeatures: Set<String> = [] {
        didSet {
            let array = Array(visitedFeatures)
            UserDefaults.standard.set(array, forKey: "visitedFeatures")
        }
    }
    
    init() {
        self.timeWalkDuration = UserDefaults.standard.double(forKey: "timeWalkDuration")
        self.referenceFrameSwitches = UserDefaults.standard.integer(forKey: "referenceFrameSwitches")
        
        if let savedFeatures = UserDefaults.standard.array(forKey: "visitedFeatures") as? [String] {
            self.visitedFeatures = Set(savedFeatures)
        }
    }
    
    // MARK: - Actions
    
    func addTimeWalkDuration(_ duration: TimeInterval) {
        timeWalkDuration += duration
    }
    
    func incrementReferenceFrameSwitches() {
        referenceFrameSwitches += 1
    }
    
    func markFeatureVisited(_ featureId: String) {
        if !visitedFeatures.contains(featureId) {
            visitedFeatures.insert(featureId)
        }
    }
    
    var conceptsExploredCount: Int {
        return visitedFeatures.count
    }
}
