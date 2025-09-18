import SwiftUI
import SpriteKit

struct GameView: View {
    @State var scene: GameScene? = nil
    @State var playerDirection = CGVector(dx: 0, dy: 0)
    @State var shootingDirection = CGVector(dx: 0, dy: 0)

    var body: some View {
        GeometryReader { geo in
            ZStack {
                SpriteView(scene: scene ?? GameScene(size: CGSize(width: geo.size.width, height: geo.size.height)))
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
                        // Left joystick
                        // Left joystick
                        VirtualJoystickView(isShootingJoystick: false) { vector in
                            playerDirection = vector
                            if let player = scene?.players.first {
                                player.move(direction: vector)
                            }
                        }
                        
                        Spacer()
                        
                        // Right joystick
                        VirtualJoystickView(isShootingJoystick: true) { vector in
                            shootingDirection = vector
                            if let player = scene?.players.first, let scene = scene {
                                player.rotateToDirection(direction: vector)
                                player.shoot(direction: vector, in: scene)  // ✅ scene is safely unwrapped
                            }
                        }

                    }
                    .padding()
                }
            }
        }
    }
}
