import SpriteKit

class Weapon {
    enum WeaponType {
        case machineGun
        case heavyMachineGun
        case laserGun
        case shotgun
    }

    var type: WeaponType

    init(type: WeaponType) {
        self.type = type
    }

    func fire(from position: CGPoint, direction: CGVector, in scene: SKScene) {
        // Create bullet
        let bullet = SKSpriteNode(imageNamed: "bullet")
        bullet.position = position
        bullet.size = CGSize(width: 15, height: 15)
        bullet.zPosition = 3

        // Fast velocity for a continuous stream
        let velocityMultiplier: CGFloat = 35.0 //higher for faster stream
        let velocity = CGVector(dx: direction.dx * velocityMultiplier,
                                dy: direction.dy * velocityMultiplier)

        let moveAction = SKAction.repeatForever(SKAction.move(by: velocity, duration: 0.05))
        bullet.run(moveAction)

        // Add bullet to scene
        scene.addChild(bullet)
    }
}
