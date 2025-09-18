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
    
    // Fire method updated to accept scene reference
    func fire(from position: CGPoint, direction: CGVector, in scene: SKScene) {
        let bullet = SKSpriteNode(imageNamed: "bullet")
        bullet.position = position
        bullet.size = CGSize(width: 15, height: 15)
        bullet.zPosition = 3
        let velocity = CGVector(dx: direction.dx * 10, dy: direction.dy * 10)
        let moveAction = SKAction.move(by: velocity, duration: 0.1)
        bullet.run(SKAction.repeatForever(moveAction))
        scene.addChild(bullet)
    }
}
