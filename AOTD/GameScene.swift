import SpriteKit

class GameScene: SKScene {
    var players: [Player] = []
    var zombies: [Zombie] = []
    var roundManager: RoundManager?
    var levelNumber: Int = 1

    override func didMove(to view: SKView) {
        backgroundColor = .brown
        print("GameScene loaded")

        // Initialize Player
        let playerSprite = SKSpriteNode(imageNamed: "player_1")
        playerSprite.size = CGSize(width: 60, height: 60)
        playerSprite.position = CGPoint(x: size.width/2, y: size.height/2)
        let weapon = Weapon(type: Weapon.WeaponType.machineGun)
        let player = Player(sprite: playerSprite, weapon: weapon)
        players.append(player)
        addChild(player.sprite)

        // Bob animation
        let bob = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 5, duration: 0.5),
            SKAction.moveBy(x: 0, y: -5, duration: 0.5)
        ])
        player.sprite.run(SKAction.repeatForever(bob))

        // Load levels and setup RoundManager
        if let levels = LevelLoader.loadLevels() {
            roundManager = RoundManager(levelData: levels)
            roundManager?.startRound(in: self)
        }
    }

    func initializeRound(with level: Level) {
        for _ in 0..<level.zombieCount {
            let zombie = Zombie(texture: SKTexture(imageNamed: "zombie"),
                                color: .clear,
                                size: CGSize(width: 50, height: 50))
            zombie.position = CGPoint(x: CGFloat.random(in: 50..<(size.width-50)),
                                      y: CGFloat.random(in: 50..<(size.height-50)))
            // Scale zombie health with level
            zombie.health = max(1, level.zombieHealth + (levelNumber - 1))
            zombie.moveSpeed = level.zombieSpeed
            zombie.zPosition = 1
            addChild(zombie)
            zombies.append(zombie)

            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.2, duration: 0.5),
                SKAction.scale(to: 1.0, duration: 0.5)
            ])
            zombie.run(SKAction.repeatForever(pulse))
        }
    }

    override func update(_ currentTime: TimeInterval) {
        guard let player = players.first else { return }

        // Update bullets
        enumerateChildNodes(withName: "bullet") { node, _ in
            if let bullet = node as? SKSpriteNode {
                // Check collision with each zombie
                for zombie in self.zombies {
                    if bullet.frame.intersects(zombie.frame) {
                        zombie.takeDamage()
                        bullet.removeFromParent()
                    }
                }
            }
        }

        // Update zombies
        for zombie in zombies {
            zombie.update(playerPosition: player.sprite.position)

            // Check collision with player
            if zombie.frame.intersects(player.sprite.frame) {
                player.takeDamage()
            }
        }
    }
}
