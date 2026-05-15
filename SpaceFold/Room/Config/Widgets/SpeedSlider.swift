import SwiftUI

struct SpeedSlider: View {
    @Binding var velocity: Double
    let maxVelocity: Double = 0.99 // Fraction of speed of light
    
    var body: some View {
        VStack(spacing: 8) {
            // Speed indicator
            HStack {
                Text("Velocity")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("\(Int(velocity * 100))% c")
                    .font(.system(.body, design: .monospaced).bold())
                    .foregroundStyle(.cyan)
            }
            
            // Custom slider
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 8)
                    
                    // Fill
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .cyan, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * velocity / maxVelocity, height: 8)
                    
                    // Thumb
                    Circle()
                        .fill(.white)
                        .frame(width: 24, height: 24)
                        .shadow(radius: 3)
                        .offset(x: (geometry.size.width - 24) * velocity / maxVelocity)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let newValue = value.location.x / geometry.size.width * maxVelocity
                                    velocity = min(max(0, newValue), maxVelocity)
                                }
                        )
                }
            }
            .frame(height: 24)
            
            // Light speed warning
            if velocity > 0.9 {
                Text("⚠️ Approaching light speed!")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Velocity slider")
        .accessibilityValue("\(Int(velocity * 100)) percent of light speed")
    }
}

#Preview {
    SpeedSlider(velocity: .constant(0.5))
        .padding()
        .background(.black)
}
