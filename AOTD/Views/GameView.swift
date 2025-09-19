// GameView.swift  (drop-in)
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

                VStack {
                    Spacer()
                    HStack {
                        VirtualJoystickView(isShootingJoystick: false) { vector in
                            let corrected = CGVector(dx: vector.dx, dy: -vector.dy)
                            playerDirection = corrected
                            scene?.players.first?.move(direction: corrected)
                        }

                        Spacer()

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
                    }
                    .padding()
                }
            }
            // 🔔 Return to main menu when GameScene posts the notification
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("AOTDExitToMainMenu"))) { _ in
                dismiss()
            }
        }
        // 🚫 Remove the system back chevron and nav bar
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}
