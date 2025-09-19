import SwiftUI
import SpriteKit

struct GameView: View {
    @State var scene: GameScene? = nil
    @State var playerDirection = CGVector(dx: 0, dy: 0)
    @State var shootingDirection = CGVector(dx: 0, dy: 0)

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Use the GameScene or a zero-sized SKScene fallback
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
                        // Left joystick: movement
                        VirtualJoystickView(isShootingJoystick: false) { vector in
                            // Invert Y-axis for SpriteKit coordinate system
                            let correctedVector = CGVector(dx: vector.dx, dy: -vector.dy)
                            playerDirection = correctedVector
                            if let player = scene?.players.first {
                                player.move(direction: correctedVector)
                            }
                        }
                        Spacer()
                        
                        //right joystick
                        VirtualJoystickView(isShootingJoystick: true) { vector in
                            let correctedVector = CGVector(dx: vector.dx, dy: -vector.dy)
                            shootingDirection = correctedVector
                            if let player = scene?.players.first, let scene = scene {
                                player.updateShootingDirection(direction: correctedVector)
                                if !player.isShooting {
                                    player.startShooting(in: scene)
                                }
                            }
                        } onRelease: {
                            if let player = scene?.players.first {
                                player.stopShooting()
                            }
                        }

                    }
                    .padding()
                }
            }
        }
    }
}
