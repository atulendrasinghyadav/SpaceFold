import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif
import UIKit

// MARK: - Cached Formatter

private let chatTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return formatter
}()

// MARK: - SpaceFold Chat View

struct SpaceFoldChatView: View {
    let contextHint: String?
    
    @State private var chatService: SpaceFoldChatService
    @State private var inputText = ""
    @State private var showSuggestions = true
    @FocusState private var isInputFocused: Bool
    
    init(contextHint: String? = nil) {
        self.contextHint = contextHint
        self._chatService = State(initialValue: SpaceFoldChatService(contextHint: contextHint))
    }
    
    var body: some View {
        ZStack {
            // Background
            ChatSpaceBackground()
            
            VStack(spacing: 0) {
                // Messages Area
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 16) {
                            // Welcome header
                            if chatService.messages.isEmpty {
                                ChatWelcomeHeader(contextHint: contextHint)
                                    .padding(.top, 20)
                                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            }
                            
                            // Suggested questions
                            if chatService.messages.isEmpty && showSuggestions {
                                SuggestedQuestionsGrid(
                                    questions: chatService.suggestedQuestions,
                                    onSelect: { question in
                                        withAnimation(.spring(response: 0.3)) {
                                            showSuggestions = false
                                        }
                                        Task {
                                            await chatService.ask(question)
                                        }
                                    }
                                )
                                .padding(.horizontal, 16)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }
                            
                            // Messages
                            ForEach(chatService.messages) { message in
                                ChatBubbleView(message: message)
                                    .id(message.id)
                                    .transition(.asymmetric(
                                        insertion: .opacity.combined(with: .move(edge: .bottom)).combined(with: .scale(scale: 0.95)),
                                        removal: .opacity
                                    ))
                            }
                            
                            // Typing indicator
                            if chatService.isGenerating {
                                TypingIndicatorView()
                                    .id("typing")
                                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                            }
                            
                            // Bottom spacer
                            Color.clear.frame(height: 8)
                                .id("bottom")
                        }
                        .padding(.horizontal, 16)
                        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: chatService.messages.count)
                        .animation(.easeInOut(duration: 0.3), value: chatService.isGenerating)
                    }
                    .onChange(of: chatService.messages.count) {
                        withAnimation(.spring(response: 0.3)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                    .onChange(of: chatService.isGenerating) {
                        if chatService.isGenerating {
                            withAnimation(.spring(response: 0.3)) {
                                proxy.scrollTo("typing", anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Input bar
                ChatInputBar(
                    text: $inputText,
                    isGenerating: chatService.isGenerating,
                    isFocused: $isInputFocused,
                    onSend: sendMessage
                )
            }
        }
        .navigationTitle(contextTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !chatService.messages.isEmpty {
                    Button {
                        withAnimation(.spring(response: 0.4)) {
                            chatService.clearConversation()
                            showSuggestions = true
                        }
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .accessibilityLabel("Clear conversation")
                    .accessibilityHint("Removes all messages and starts a new conversation")
                }
            }
        }
    }
    
    private var contextTitle: String {
        switch contextHint {
        case "spacetime_fabric": return "Ask about Spacetime"
        case "time_dilation": return "Ask about Time Dilation"
        case "observer_frames": return "Ask about Observers"
        default: return "Ask SpaceFold"
        }
    }
    
    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        inputText = ""
        isInputFocused = false
        
        withAnimation(.spring(response: 0.3)) {
            showSuggestions = false
        }
        
        Task {
            await chatService.ask(text)
            UIAccessibility.post(
                notification: .announcement,
                argument: "SpaceFold responded"
            )
        }
    }
}

// MARK: - Chat Space Background

struct ChatSpaceBackground: View {
    var body: some View {
        ZStack {
            // Deep space base
            Color(red: 0.01, green: 0.01, blue: 0.04)
                .ignoresSafeArea()
            
            // Subtle nebula glow
            RadialGradient(
                colors: [
                    Color.purple.opacity(0.08),
                    Color.cyan.opacity(0.04),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 50,
                endRadius: 400
            )
            .ignoresSafeArea()
            
            RadialGradient(
                colors: [
                    Color.cyan.opacity(0.06),
                    Color.clear
                ],
                center: .bottomLeading,
                startRadius: 30,
                endRadius: 350
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Chat Welcome Header

struct ChatWelcomeHeader: View {
    let contextHint: String?
    
    @State private var glowOpacity: Double = 0.4
    @State private var iconScale: CGFloat = 0.8
    
    var body: some View {
        VStack(spacing: 16) {
            // Animated icon
            ZStack {
                // Glow rings
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.cyan.opacity(glowOpacity), .purple.opacity(glowOpacity * 0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 90, height: 90)
                    .scaleEffect(iconScale * 1.3)
                
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.purple.opacity(glowOpacity * 0.5), .cyan.opacity(glowOpacity * 0.3)],
                            startPoint: .bottomLeading,
                            endPoint: .topTrailing
                        ),
                        lineWidth: 1
                    )
                    .frame(width: 110, height: 110)
                    .scaleEffect(iconScale * 1.5)
                
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 38, weight: .thin))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(iconScale)
            }
            
            VStack(spacing: 8) {
                Text("SpaceFold AI")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                Text(subtitle)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.bottom, 20)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                glowOpacity = 0.8
            }
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                iconScale = 1.0
            }
        }
    }
    
    private var subtitle: String {
        switch contextHint {
        case "spacetime_fabric":
            return "Ask me about spacetime curvature\nand general relativity"
        case "time_dilation":
            return "Ask me about time dilation\nand special relativity"
        case "observer_frames":
            return "Ask me about reference frames\nand relative motion"
        default:
            return "Your theoretical physics professor\nAsk me anything about Einstein's universe"
        }
    }
}

// MARK: - Suggested Questions Grid

struct SuggestedQuestionsGrid: View {
    let questions: [String]
    let onSelect: (String) -> Void
    
    var body: some View {
        VStack(spacing: 10) {
            Text("SUGGESTED QUESTIONS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.3))
                .tracking(1.5)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ], spacing: 10) {
                ForEach(questions, id: \.self) { question in
                    Button {
                        onSelect(question)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkle")
                                .font(.system(size: 10))
                                .foregroundStyle(.cyan.opacity(0.6))
                            
                            Text(question)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.8))
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.white.opacity(0.04))
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Sends this question to SpaceFold AI")
                }
            }
        }
    }
}

// MARK: - Chat Bubble View

struct ChatBubbleView: View {
    let message: ChatMessage
    
    @State private var appeared = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if message.role == .user {
                Spacer(minLength: 60)
            }
            
            if message.role == .assistant {
                // AI avatar
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.purple.opacity(0.4), .cyan.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 30, height: 30)
                    
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.white.opacity(0.95))
                    .lineSpacing(3)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        bubbleBackground
                    )
                
                Text(timeString)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.white.opacity(0.25))
                    .padding(.horizontal, 4)
            }
            
            if message.role == .assistant {
                Spacer(minLength: 40)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                appeared = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message.role == .user ? "You said: \(message.content)" : "SpaceFold said: \(message.content)")
    }
    
    @ViewBuilder
    private var bubbleBackground: some View {
        if message.role == .user {
            // User bubble — cyan glass
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.cyan.opacity(0.25),
                            Color.cyan.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.cyan.opacity(0.3), .cyan.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        } else {
            // AI bubble — purple glass
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.purple.opacity(0.15),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.purple.opacity(0.2), .white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        }
    }
    
    private var timeString: String {
        chatTimeFormatter.string(from: message.timestamp)
    }
}

// MARK: - Typing Indicator

struct TypingIndicatorView: View {
    @State private var dot1: CGFloat = 0
    @State private var dot2: CGFloat = 0
    @State private var dot3: CGFloat = 0
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // AI avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.4), .cyan.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 30, height: 30)
                
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            }
            
            HStack(spacing: 6) {
                DotView(offset: dot1)
                DotView(offset: dot2)
                DotView(offset: dot3)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.purple.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                    )
            )
            
            Spacer(minLength: 40)
        }
        .accessibilityLabel("SpaceFold is thinking")
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                dot1 = -6
            }
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(0.1)) {
                dot2 = -6
            }
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(0.2)) {
                dot3 = -6
            }
        }
    }
}

private struct DotView: View {
    let offset: CGFloat
    
    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [.cyan.opacity(0.8), .purple.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 8, height: 8)
            .offset(y: offset)
    }
}

// MARK: - Chat Input Bar

struct ChatInputBar: View {
    @Binding var text: String
    let isGenerating: Bool
    @FocusState.Binding var isFocused: Bool
    let onSend: () -> Void
    
    @State private var glowIntensity: Double = 0.3
    
    var body: some View {
        HStack(spacing: 12) {
            // Text field
            HStack(spacing: 8) {
                TextField("Ask about physics...", text: $text, axis: .vertical)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.white)
                    .lineLimit(1...4)
                    .focused($isFocused)
                    .tint(.cyan)
                    .onSubmit {
                        onSend()
                    }
                    .accessibilityLabel("Message input")
                    .accessibilityHint("Type a physics question to ask SpaceFold AI")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(
                                isFocused
                                    ? LinearGradient(
                                        colors: [.cyan.opacity(0.4), .purple.opacity(0.3)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                    : LinearGradient(
                                        colors: [.white.opacity(0.1), .white.opacity(0.05)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                lineWidth: 1
                            )
                    )
            )
            
            // Send button
            Button(action: onSend) {
                ZStack {
                    Circle()
                        .fill(
                            canSend
                                ? LinearGradient(
                                    colors: [.cyan, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [.gray.opacity(0.3), .gray.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                        .frame(width: 44, height: 44)
                    
                    // Glow effect when active
                    if canSend {
                        Circle()
                            .fill(.cyan.opacity(glowIntensity * 0.3))
                            .frame(width: 52, height: 52)
                            .blur(radius: 8)
                    }
                    
                    Image(systemName: isGenerating ? "stop.fill" : "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .disabled(!canSend)
            .animation(.easeInOut(duration: 0.2), value: canSend)
            .accessibilityLabel(isGenerating ? "Stop generating" : "Send message")
            .accessibilityHint(isGenerating ? "Stops the AI response" : "Sends your question to SpaceFold AI")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .background(
                    Rectangle()
                        .fill(Color.black.opacity(0.5))
                )
                .ignoresSafeArea(edges: .bottom)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowIntensity = 0.7
            }
        }
    }
    
    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGenerating
    }
}

// MARK: - Preview

#Preview {
    SpaceFoldChatView()
}
