import SpriteKit

class Weapon {
    enum WeaponType {
        case machineGun
        case heavyMachineGun
        case laserGun
        case shotgun
    }

    var type: WeaponType
    var damage: Int
    var fireRate: TimeInterval

    init(type: WeaponType) {
        self.type = type

        // Set damage and fire rate based on type
        switch type {
        case .machineGun:
            damage = 1
            fireRate = 0.1
        case .heavyMachineGun:
            damage = 2
            fireRate = 0.08
        case .laserGun:
            damage = 2  // Base damage; implement area effect separately
            fireRate = 0.12
        case .shotgun:
            damage = 3
            fireRate = 0.25
        }
    }

    func fire(from position: CGPoint, direction: CGVector, in scene: SKScene) {
        // Create bullet
        let bullet = SKSpriteNode(imageNamed: "bullet")
        bullet.name = "bullet" // Important for collision detection
        bullet.position = position
        bullet.size = CGSize(width: 15, height: 15)
        bullet.zPosition = 3

        // Add bullet to scene
        scene.addChild(bullet)

        // Fast velocity for a continuous stream
        let velocityMultiplier: CGFloat = 35.0 // Adjust for bullet speed
        let velocity = CGVector(dx: direction.dx * velocityMultiplier,
                                dy: direction.dy * velocityMultiplier)

        let moveAction = SKAction.repeatForever(SKAction.move(by: velocity, duration: 0.05))
        bullet.run(moveAction)
    }
}
