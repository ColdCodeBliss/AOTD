import SpriteKit

class GameScene: SKScene {
    var players: [Player] = []
    var zombies: [Zombie] = []
    var roundManager: RoundManager?
    
    override func didMove(to view: SKView) {
        backgroundColor = .green
        print("GameScene loaded")
        
        // Initialize Player
        let playerSprite = SKSpriteNode(color: .blue, size: CGSize(width: 50, height: 50))
        playerSprite.position = CGPoint(x: size.width / 2, y: size.height / 2)
        let weapon = Weapon(type: .machineGun)
        let player = Player(sprite: playerSprite, weapon: weapon)
        players.append(player)
        addChild(player.sprite)
        
        // Load levels and setup RoundManager
        if let levels = LevelLoader.loadLevels() {
            roundManager = RoundManager(levelData: levels)
            roundManager?.startRound(in: self)
        }
    }
    
    func initializeRound(with level: Level) {
        // Background
        let bg = SKSpriteNode(color: .brown, size: size)
        bg.position = CGPoint(x: size.width/2, y: size.height/2)
        bg.zPosition = -1
        addChild(bg)
        
        // Spawn zombies
        for _ in 0..<level.zombieCount {
            let zombie = Zombie(color: .red, size: CGSize(width: 40, height: 40))
            zombie.position = CGPoint(x: CGFloat.random(in: 0..<size.width),
                                      y: CGFloat.random(in: 0..<size.height))
            zombie.moveSpeed = level.zombieSpeed
            zombie.health = level.zombieHealth
            addChild(zombie)
            zombies.append(zombie)
        }
    }
    
    override func update(_ currentTime: TimeInterval) {
        guard let player = players.first else { return }
        
        // Update all zombies
        for zombie in zombies {
            zombie.update(playerPosition: player.sprite.position)
            
            // Collision check
            if zombie.frame.intersects(player.sprite.frame) {
                player.takeDamage()
            }
        }
    }

}
