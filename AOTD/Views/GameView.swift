import SwiftUI
import SpriteKit

struct GameView: View {
    @State private var scene: GameScene?

    var body: some View {
        GeometryReader { geometry in
            Group {
                if let scene {
                    SpriteView(scene: scene)
                        .edgesIgnoringSafeArea(.all)
                } else {
                    // Placeholder while the scene is being created
                    Color.clear
                        .edgesIgnoringSafeArea(.all)
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
