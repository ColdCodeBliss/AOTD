import SwiftUI
import CoreGraphics

struct VirtualJoystickView: View {
    // MARK: - Properties
    var isShootingJoystick: Bool
    var onMove: (CGVector) -> Void
    var onRelease: (() -> Void)? = nil

    // Internal state
    @State private var dragLocation: CGPoint = .zero
    @State private var isDragging: Bool = false

    // Joystick configuration
    private let joystickSize: CGFloat = 150
    private let knobSize: CGFloat = 60

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: joystickSize, height: joystickSize)

            // Knob circle
            Circle()
                .fill(isShootingJoystick ? Color.red : Color.blue)
                .frame(width: knobSize, height: knobSize)
                .offset(x: dragLocation.x, y: dragLocation.y)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            self.isDragging = true

                            // Calculate displacement relative to center
                            let dx = value.translation.width
                            let dy = value.translation.height

                            // Limit the knob to joystick radius
                            let radius = (joystickSize - knobSize) / 2
                            let distance = sqrt(dx*dx + dy*dy)
                            let clampedDistance = min(distance, radius)
                            let angle = atan2(dy, dx)
                            let offsetX = cos(angle) * clampedDistance
                            let offsetY = sin(angle) * clampedDistance

                            self.dragLocation = CGPoint(x: offsetX, y: offsetY)

                            // Convert offset to CGVector in range [-1,1]
                            let vector = CGVector(dx: offsetX / radius, dy: offsetY / radius)
                            self.onMove(vector)
                        }
                        .onEnded { _ in
                            // Reset knob to center
                            self.dragLocation = .zero
                            self.isDragging = false
                            // Notify release
                            self.onRelease?()
                        }
                )
        }
        .frame(width: joystickSize, height: joystickSize)
    }
}
