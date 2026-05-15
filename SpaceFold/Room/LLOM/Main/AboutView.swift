import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
    //                    .foregroundStyle(
    //                        LinearGradient(
    //                            colors: [.white.opacity(0.9), .cyan.opacity(0.7)],
    //                            startPoint: .topLeading,
    //                            endPoint: .bottomTrailing
    //                        )
    //                    )
    //                    .opacity(0.2)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .cyan.opacity(0.2), radius: 40)
                        .padding(.top , 20)
                    
                    Text("SpaceFold")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .accessibilityAddTraits(.isHeader)
                    
                    Text("Visualizing Einstein's Universe")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 20)
                
                // Why SpaceFold
                AboutSectionCard(title: "Why SpaceFold?", icon: "sparkles") {
                    Text("General Relativity is often taught through abstract equations that are hard to visualize. SpaceFold bridges the gap between math and intuition, turning your environment into a laboratory for Einstein's biggest ideas.")
                }
                
                // How to Use
                AboutSectionCard(title: "How to Use", icon: "camera.viewfinder") {
                    VStack(alignment: .leading, spacing: 12) {
                        InstructionRow(icon: "light.max", text: "Ensure you are in a well-lit area.")
                        InstructionRow(icon: "square.dashed", text: "Find a textured surface (floor or table) for AR placement.")
                        InstructionRow(icon: "hand.tap", text: "Tap the screen to place objects or interact with them.")
                        InstructionRow(icon: "arrow.up.and.down.and.arrow.left.and.right", text: "Move your device around to explore from different angles.")
                        InstructionRow(icon: "camera", text: "Change the mode of the screen by toggle the camera button.")
                    }
                }
                
                // Features Header
                HStack {
                    Text("Features")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    Spacer()
                }
                .padding(.horizontal, 4)
                
                // Feature: Spacetime Fabric
                AboutFeatureCard(
                    title: "Spacetime Fabric",
                    subtitle: "General Relativity",
                    icon: "network",
                    color: .purple
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Visualize how mass warps the fabric of space itself. In General Relativity, gravity isn't a force, but the curvature of spacetime caused by matter.")
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Divider().background(.white.opacity(0.2))
                        
                        Text("Interactions:")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.white.opacity(0.8))
                        
                        InteractionRow(action: "Drag", description: "Move the mass to bend the grid.")
                        InteractionRow(action: "Pinch", description: "Change the mass size (heavier = deeper curve).")
                        InteractionRow(action: "Tap", description: "Release light particles to see them follow the curved path.")
                    }
                }
                
                // Feature: Time Walk
                AboutFeatureCard(
                    title: "Time Walk",
                    subtitle: "Time Dilation",
                    icon: "clock.arrow.circlepath",
                    color: .cyan
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("The faster you move through space, the slower you move through time. Experience the 'Twin Paradox' by accelerating a rocket to near light speed.")
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Divider().background(.white.opacity(0.2))
                        
                        Text("Interactions:")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.white.opacity(0.8))
                        
                        InteractionRow(action: "Slider", description: "Increase velocity closely to the speed of light (c).")
                        InteractionRow(action: "Compare", description: "Watch the Rocket clock slow down compared to the Earth clock.")
                        InteractionRow(action: "Prespective", description: "Change the prespective of the user to Earth or Rocket.")
                    }
                }
                
                // Feature: Observer Frames
                AboutFeatureCard(
                    title: "Observer Frames",
                    subtitle: "Relative Motion",
                    icon: "eye.trianglebadge.exclamationmark",
                    color: .orange
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Motion is relative. There is no single 'correct' view of an event. See how the path of a thrown ball looks completely different depending on your frame of reference.")
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Divider().background(.white.opacity(0.2))
                        
                        Text("Interactions:")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.white.opacity(0.8))
                        
                        InteractionRow(action: "Switch View", description: "Toggle between Train (dropper) and Platform (observer) perspectives.")
                        InteractionRow(action: "Throw", description: "Tap to throw the ball and trace its path.")
                    }
                }
                
                // Footer
                VStack(spacing: 8) {
                    Text("Swift Student Challenge 2025")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.6))
                    
                    Text("Designed & Developed by Atulendra Singh Yadav")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 20)
        }
        .background(SpaceBackgroundSimple())
        .navigationTitle("About SpaceFold")
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

// MARK: - Reusable Components

struct AboutSectionCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(.cyan)
                
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .accessibilityAddTraits(.isHeader)
                
                Spacer()
            }
            
            content
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.white.opacity(0.8))
                .lineSpacing(4)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.2))
                )
        )
    }
}

struct AboutFeatureCard<Content: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let content: Content
    
    init(title: String, subtitle: String, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .accessibilityAddTraits(.isHeader)
                    
                    Text(subtitle)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(color)
                        .textCase(.uppercase)
                }
                
                Spacer()
                
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(color)
            }
            .padding(20)
            .background(color.opacity(0.1))
            
            // Content
            VStack(alignment: .leading, spacing: 12) {
                content
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineSpacing(3)
            }
            .padding(20)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.3))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(color.opacity(0.3), lineWidth: 1)
        )
    }
}

struct InstructionRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 20, alignment: .center)
            
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.8))
        }
        .accessibilityElement(children: .combine)
    }
}

struct InteractionRow: View {
    let action: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("• " + action + ":")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
            
            Text(description)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.7))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(action): \(description)")
    }
}

#Preview {
    AboutView()
}
