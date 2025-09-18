import SpriteKit

class Level {
    var terrain: String
    var zombieCount: Int
    var zombieHealth: Int
    var zombieSpeed: CGFloat
    
    init(terrain: String, zombieCount: Int, zombieHealth: Int, zombieSpeed: CGFloat) {
        self.terrain = terrain
        self.zombieCount = zombieCount
        self.zombieHealth = zombieHealth
        self.zombieSpeed = zombieSpeed
    }
}
