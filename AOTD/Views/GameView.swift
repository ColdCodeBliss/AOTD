import SwiftUI
import SpriteKit

struct GameView: View {
    @State private var scene: GameScene?
    
    @State private var playerDirection = CGVector(dx: 0, dy: 0)
    @State private var shootingDirection = CGVector(dx: 0, dy: 0)
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let scene = scene {
                    SpriteView(scene: scene)
                        .edgesIgnoringSafeArea(.all)
                } else {
                    Color.black
                        .ignoresSafeArea()
                }
                
                VStack {
                    Spacer()
                    HStack {
                        // Movement joystick
                        VirtualJoystickView(isShootingJoystick: false) { vector in
                            playerDirection = vector
                            if let player = scene?.players.first {
                                player.move(direction: vector)
                            }
                        }
                        Spacer()
                        // Shooting joystick
                        VirtualJoystickView(isShootingJoystick: true) { vector in
                            shootingDirection = vector
                            if let player = scene?.players.first {
                                player.rotateToDirection(direction: vector)
                                player.shoot(direction: vector)
                            }
                        }
                    }
                    .padding()
                }
            }
            .onAppear {
                if scene == nil {
                    let newScene = GameScene(size: geometry.size)
                    newScene.scaleMode = .resizeFill
                    scene = newScene
                }
            }
        }
    }
}
