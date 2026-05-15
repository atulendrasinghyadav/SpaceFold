import SwiftUI
import Observation

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Chat Message Model

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: Role
    let content: String
    let timestamp: Date
    
    enum Role {
        case user
        case assistant
    }
    
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - SpaceFold Chat Service

@MainActor
@Observable
class SpaceFoldChatService {
    var messages: [ChatMessage] = []
    var isGenerating = false
    var errorMessage: String?
    
    @ObservationIgnored
    private var session: Any?
    private let contextHint: String?
    
    /// Context-specific suggested questions
    var suggestedQuestions: [String] {
        switch contextHint {
        case "spacetime_fabric":
            return [
                "What is space fabric?",
                "How does mass bend space?",
                "Why do planets orbit the Sun?",
                "What is a geodesic?"
            ]
        case "time_dilation":
            return [
                "What is time dilation?",
                "Explain the twin paradox",
                "Why does speed affect time?",
                "What is the Lorentz factor?"
            ]
        case "observer_frames":
            return [
                "What is a reference frame?",
                "Why is motion relative?",
                "What is Galilean relativity?",
                "Is there absolute motion?"
            ]
        default:
            return [
                "What is wormhole?",
                "Explain time dilation simply",
                "What is a reference frame?",
                "How gravity affects time?"
            ]
        }
    }
    
    init(contextHint: String? = nil) {
        self.contextHint = contextHint
    }
    
    /// Initialize the language model session
    private func initializeSession() {
        let contextInstruction: String
        switch contextHint {
        case "spacetime_fabric":
            contextInstruction = "The user is currently exploring the Spacetime Fabric AR experience, which demonstrates how mass curves space. Focus your answers on general relativity, spacetime curvature, gravity as geometry, and geodesics."
        case "time_dilation":
            contextInstruction = "The user is currently exploring the Time Walk AR experience, which demonstrates time dilation. Focus your answers on special relativity, time dilation, the twin paradox, and the Lorentz factor."
        case "observer_frames":
            contextInstruction = "The user is currently exploring the Observer Frames AR experience, which demonstrates relative motion. Focus your answers on reference frames, Galilean relativity, and how observations differ between observers."
        default:
            contextInstruction = "The user is exploring SpaceFold, an app about Einstein's theories of relativity."
        }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let newSession = LanguageModelSession(
                instructions: """
                You are a theoretical physics professor and your name is SpaceFold.
                Explain concepts clearly and in simple language with easy examples.
                Be concise but precise.
                Make your response short, accurate and relevant.
                Make your response lesser than 100 words and provide response in two paragraphs.
                Avoid unnecessary storytelling.
                Use analogies from everyday life to make physics intuitive.
                \(contextInstruction)
                """
            )
            self.session = newSession
        } else {
            self.session = nil
        }
        #else
        self.session = nil
        #endif
    }
    
    /// Send a question and get a response
    func ask(_ question: String) async {
        // Add user message
        let userMessage = ChatMessage(role: .user, content: question, timestamp: Date())
        messages.append(userMessage)
        
        isGenerating = true
        errorMessage = nil
        
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else {
            isGenerating = false
            let msg = ChatMessage(
                role: .assistant,
                content: "Apple Intelligence features require iOS 26 or later on supported devices.",
                timestamp: Date()
            )
            self.errorMessage = "Requires iOS 26 or later."
            messages.append(msg)
            return
        }
        
        do {
            let model = SystemLanguageModel.default
            
            // Check availability with detailed handling
            switch model.availability {
            case .available:
                break
            case .unavailable(let reason):
                isGenerating = false
                let reasonMessage: String
                switch reason {
                case .deviceNotEligible:
                    reasonMessage = "This device doesn't support Apple Intelligence. You need an iPhone 15 Pro or later, or an iPad/Mac with an M-series chip."
                case .appleIntelligenceNotEnabled:
                    reasonMessage = "Apple Intelligence is not enabled. Please go to Settings → Apple Intelligence & Siri and enable it. Also make sure the on-device model has finished downloading."
                case .modelNotReady:
                    reasonMessage = "The AI model is still downloading. Please wait a few minutes and try again. You can check the progress in Settings → Apple Intelligence & Siri."
                @unknown default:
                    reasonMessage = "Apple Intelligence is not available right now. Please check Settings → Apple Intelligence & Siri."
                }
                errorMessage = reasonMessage
                let errorMsg = ChatMessage(
                    role: .assistant,
                    content: reasonMessage,
                    timestamp: Date()
                )
                messages.append(errorMsg)
                return
            @unknown default:
                isGenerating = false
                errorMessage = "Apple Intelligence is not available. Please ensure it is enabled in Settings."
                let errorMsg = ChatMessage(
                    role: .assistant,
                    content: "Apple Intelligence is not available right now. Please check Settings → Apple Intelligence & Siri.",
                    timestamp: Date()
                )
                messages.append(errorMsg)
                return
            }
            
            // Initialize session if needed
            if session == nil {
                initializeSession()
            }
            
            guard let activeSession = session as? LanguageModelSession else { return }
            
            // Get response
            let response = try await activeSession.respond(to: question)
            
            let assistantMessage = ChatMessage(
                role: .assistant,
                content: response.content,
                timestamp: Date()
            )
            messages.append(assistantMessage)
        } catch {
            // Reset session on error so it can be re-created on next attempt
            session = nil
            
            let errorDescription = error.localizedDescription
            let userFriendlyMessage: String
            
            // Check for the specific model catalog / asset error
            if errorDescription.contains("modelcatalog") ||
               errorDescription.contains("no underlying assets") ||
               errorDescription.contains("UnifiedAssetFramework") ||
               errorDescription.contains("consistency token") ||
                errorDescription.contains("GenerationError") {
                userFriendlyMessage = """
                The on-device AI model isn't ready yet. Please try these steps:
                
                1. Go to Settings → Apple Intelligence & Siri (If not found it means your software or device is not compatible) and make sure Apple Intelligence is enabled.
                2. Set Siri language to English (United States).
                3. Wait for the model to finish downloading (this can take a few minutes).
                4. Restart the app and try again.
                """
            } else {
                userFriendlyMessage = "Something went wrong: \(errorDescription). Please try again."
            }
            
            errorMessage = userFriendlyMessage
            let errorMsg = ChatMessage(
                role: .assistant,
                content: userFriendlyMessage,
                timestamp: Date()
            )
            messages.append(errorMsg)
        }
        
        isGenerating = false
        #else
        // FoundationModels not available at compile time
        isGenerating = false
        let msg = ChatMessage(
            role: .assistant,
            content: "Apple Intelligence features require iOS 26 or later on supported devices.",
            timestamp: Date()
        )
        self.errorMessage = "Requires iOS 26 or later."
        messages.append(msg)
        #endif
    }
    
    /// Clear conversation and start fresh
    func clearConversation() {
        messages.removeAll()
        session = nil
        errorMessage = nil
    }
}
