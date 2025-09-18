import SwiftUI

struct VirtualJoystickView: View {
    var isShootingJoystick: Bool
    
    var body: some View {
        Circle()
            .strokeBorder(Color.white, lineWidth: 3)
            .background(Circle().fill(Color.gray.opacity(0.5)))
            .frame(width: 150, height: 150)
            .overlay(
                Text(isShootingJoystick ? "Shoot" : "Move")
                    .foregroundColor(.white)
            )
    }
}
