import SpriteKit

class RoundManager {
    var currentRound: Int = 0
    var maxRounds: Int = 5
    var levelData: [Level]
    
    init(levelData: [Level]) {
        self.levelData = levelData
    }
    
    func startRound(in scene: GameScene) {
        guard currentRound < maxRounds else { return }
        currentRound += 1
        if levelData.indices.contains(currentRound - 1) {
            let level = levelData[currentRound - 1]
            scene.initializeRound(with: level)
        }
    }
}
