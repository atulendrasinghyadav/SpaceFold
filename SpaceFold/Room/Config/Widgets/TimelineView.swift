import SwiftUI

struct TimelineEvent: Identifiable {
    let id = UUID()
    let name: String
    let time: Double
    let color: Color
}

struct EventTimelineView: View {
    let events: [TimelineEvent]
    @Binding var currentTime: Double
    let maxTime: Double
    
    var body: some View {
        VStack(spacing: 12) {
            // Time display
            Text("t = \(String(format: "%.2f", currentTime))s")
                .font(.system(.title3, design: .monospaced).bold())
                .foregroundStyle(.white)
            
            // Timeline track
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track background
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 4)
                    
                    // Events
                    ForEach(events) { event in
                        Circle()
                            .fill(event.color)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle()
                                    .stroke(.white, lineWidth: 2)
                            )
                            .offset(x: geometry.size.width * event.time / maxTime - 8)
                    }
                    
                    // Playhead
                    Rectangle()
                        .fill(.white)
                        .frame(width: 2, height: 24)
                        .offset(x: geometry.size.width * currentTime / maxTime)
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            currentTime = min(max(0, value.location.x / geometry.size.width * maxTime), maxTime)
                        }
                )
            }
            .frame(height: 24)
            
            // Event labels
            HStack {
                ForEach(events) { event in
                    Text(event.name)
                        .font(.caption2)
                        .foregroundStyle(event.color)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    EventTimelineView(
        events: [
            TimelineEvent(name: "Flash A", time: 0.3, color: .red),
            TimelineEvent(name: "Flash B", time: 0.7, color: .blue)
        ],
        currentTime: .constant(0.5),
        maxTime: 1.0
    )
    .padding()
    .background(.black)
}
