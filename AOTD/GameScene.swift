import SpriteKit

class GameScene: SKScene {
    var players: [Player] = []
    var zombies: [Zombie] = []
    var roundManager: RoundManager?

    override func didMove(to view: SKView) {
        // Add a visible background
        let bg = SKSpriteNode(color: .brown, size: size)
        bg.position = CGPoint(x: size.width/2, y: size.height/2)
        bg.zPosition = -1
        addChild(bg)

        print("GameScene loaded")

        // Initialize Player
        let playerSprite = SKSpriteNode(imageNamed: "player_1")
        playerSprite.size = CGSize(width: 60, height: 60)
        playerSprite.position = CGPoint(x: size.width/2, y: size.height/2)

        // Explicitly reference WeaponType and call init with argument
        let weapon = Weapon(type: Weapon.WeaponType.machineGun)
        let player = Player(sprite: playerSprite, weapon: weapon)
        players.append(player)
        addChild(player.sprite)


        // Player bob animation
        let bob = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 5, duration: 0.5),
            SKAction.moveBy(x: 0, y: -5, duration: 0.5)
        ])
        player.sprite.run(SKAction.repeatForever(bob))

        // Load levels and setup RoundManager
        if let levels = LevelLoader.loadLevels() {
            roundManager = RoundManager(levelData: levels)
            roundManager?.startRound(in: self)
        } else {
            print("No levels found! Please check levels.json")
        }
    }

    func initializeRound(with level: Level) {
        // Spawn zombies
        for i in 0..<level.zombieCount {
            let zombie = Zombie(texture: SKTexture(imageNamed: "zombie"), color: .clear, size: CGSize(width: 50, height: 50))
            
            // Random position within the scene bounds, avoiding edges
            zombie.position = CGPoint(x: CGFloat.random(in: 50..<(size.width-50)),
                                      y: CGFloat.random(in: 50..<(size.height-50)))
            zombie.moveSpeed = level.zombieSpeed
            zombie.health = level.zombieHealth
            zombie.zPosition = 1
            addChild(zombie)
            zombies.append(zombie)

            // Simple pulse animation to make zombies noticeable
            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.2, duration: 0.5),
                SKAction.scale(to: 1.0, duration: 0.5)
            ])
            zombie.run(SKAction.repeatForever(pulse))
            
            print("Spawned zombie at \(zombie.position)")
        }
    }

    override func update(_ currentTime: TimeInterval) {
        guard let player = players.first else { return }

        // Update all zombies
        for zombie in zombies {
            zombie.update(playerPosition: player.sprite.position)
            
            // Debug print zombie position
            print("Zombie position: \(zombie.position)")

            // Collision check
            if zombie.frame.intersects(player.sprite.frame) {
                player.takeDamage()
                print("Player took damage! Health: \(player.health)")
            }
        }
    }
}
