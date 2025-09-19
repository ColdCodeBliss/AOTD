import SwiftUI
import SpriteKit
import Combine

struct GameView: View {
    @Environment(\.dismiss) private var dismiss

    @State var scene: GameScene? = nil
    @State var playerDirection = CGVector(dx: 0, dy: 0)
    @State var shootingDirection = CGVector(dx: 0, dy: 0)

    var body: some View {
        GeometryReader { geo in
            ZStack {
                SpriteView(scene: scene ?? SKScene(size: .zero))
                    .ignoresSafeArea()
                    .onAppear {
                        if scene == nil {
                            let newScene = GameScene(size: geo.size)
                            newScene.scaleMode = .resizeFill
                            scene = newScene
                        }
                    }

                // Adaptive joystick sizing & placement
                let insets = geo.safeAreaInsets
                let shorter = min(geo.size.width, geo.size.height)
                // Scale the joystick base with device size; clamp to a practical range
                let base: CGFloat = max(110, min(180, shorter * 0.22))
                let margin: CGFloat = 16
                let half = base / 2

                // Bottom-LEFT joystick (movement)
                VirtualJoystickView(isShootingJoystick: false) { vector in
                    let corrected = CGVector(dx: vector.dx, dy: -vector.dy)
                    playerDirection = corrected
                    scene?.players.first?.move(direction: corrected)
                }
                .frame(width: base, height: base)
                .position(
                    x: insets.leading + margin + half,
                    y: geo.size.height - (insets.bottom + margin + half)
                )
                .allowsHitTesting(true)

                // Bottom-RIGHT joystick (shooting)
                VirtualJoystickView(isShootingJoystick: true) { vector in
                    let corrected = CGVector(dx: vector.dx, dy: -vector.dy)
                    shootingDirection = corrected
                    if let player = scene?.players.first, let scene = scene {
                        player.updateShootingDirection(direction: corrected)
                        if !player.isShooting { player.startShooting(in: scene) }
                    }
                } onRelease: {
                    scene?.players.first?.stopShooting()
                }
                .frame(width: base, height: base)
                .position(
                    x: geo.size.width - (insets.trailing + margin + half),
                    y: geo.size.height - (insets.bottom + margin + half)
                )
                .allowsHitTesting(true)
            }
            // Return to main menu when GameScene posts the notification
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("AOTDExitToMainMenu"))) { _ in
                dismiss()
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}
