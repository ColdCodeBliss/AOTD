import SwiftUI
import SpriteKit

struct GameView: View {
    var scene: GameScene {
        let scene = GameScene(size: UIScreen.main.bounds.size)
        scene.scaleMode = .resizeFill
        return scene
    }
    
    var body: some View {
        ZStack {
            // Embed SKScene in SwiftUI
            SpriteView(scene: scene)
                .edgesIgnoringSafeArea(.all)
            
            // Overlay joystick or HUD here
            VStack {
                Spacer()
                HStack {
                    VirtualJoystickView(isShootingJoystick: false)
                    Spacer()
                    VirtualJoystickView(isShootingJoystick: true)
                }
                .padding()
            }
        }
    }
}
