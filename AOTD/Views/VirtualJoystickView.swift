import SwiftUI
import CoreGraphics

struct VirtualJoystickView: View {
    var isShootingJoystick: Bool
    var onMove: ((CGVector) -> Void)? = nil
    
    @State private var dragOffset = CGSize.zero
    
    var body: some View {
        Circle()
            .strokeBorder(Color.white, lineWidth: 3)
            .background(Circle().fill(Color.gray.opacity(0.5)))
            .frame(width: 150, height: 150)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        // Map drag to direction vector (-1 to 1)
                        let dx = max(min(value.translation.width / 75, 1), -1)
                        let dy = max(min(value.translation.height / 75, 1), -1)
                        let vector = CGVector(dx: dx, dy: dy)
                        dragOffset = value.translation
                        onMove?(vector)
                    }
                    .onEnded { _ in
                        dragOffset = .zero
                        onMove?(CGVector(dx: 0, dy: 0))
                    }
            )
            .overlay(
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .offset(dragOffset)
            )
    }
}
