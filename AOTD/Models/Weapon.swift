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
        switch type {
        case .machineGun:
            self.damage = 1
            self.fireRate = 0.09
        case .heavyMachineGun:
            self.damage = 2
            self.fireRate = 0.07
        case .laserGun:
            self.damage = 3
            self.fireRate = 0.06
        case .shotgun:
            self.damage = 1
            self.fireRate = 0.20
        }
    }

    func fire(from origin: CGPoint, direction: CGVector, in scene: SKScene) {
        let len = max(0.0001, sqrt(direction.dx * direction.dx + direction.dy * direction.dy))
        let dir = CGVector(dx: direction.dx / len, dy: direction.dy / len)

        switch type {
        case .machineGun:
            spawnStandardBullet(textureName: "bullet", size: CGSize(width: 18, height: 6),
                                speed: 700, origin: origin, dir: dir, in: scene)
        case .heavyMachineGun:
            spawnStandardBullet(textureName: "bullet", size: CGSize(width: 22, height: 8),
                                speed: 820, origin: origin, dir: dir, in: scene)
        case .laserGun:
            // Custom sprite + ricochet (now 2 bounces total)
            spawnLaserBullet(textureName: "laserbullet", size: CGSize(width: 20, height: 6),
                             speed: 900, origin: origin, dir: dir, in: scene)
        case .shotgun:
            let baseAngle = atan2(dir.dy, dir.dx)
            let spread: [CGFloat] = [-0.18, -0.09, 0.0, 0.09, 0.18]
            for s in spread {
                let a = baseAngle + s
                let v = CGVector(dx: cos(a), dy: sin(a))
                spawnStandardBullet(textureName: "bullet", size: CGSize(width: 14, height: 5),
                                    speed: 650, origin: origin, dir: v, in: scene)
            }
        }
    }

    private func spawnStandardBullet(textureName: String, size: CGSize, speed: CGFloat,
                                     origin: CGPoint, dir: CGVector, in scene: SKScene) {
        let bullet = SKSpriteNode(imageNamed: textureName)
        bullet.name = "bullet"
        bullet.size = size
        bullet.position = origin
        bullet.zPosition = 3
        bullet.zRotation = atan2(dir.dy, dir.dx)
        scene.addChild(bullet)

        let step: CGFloat = 0.05
        let velocity = CGVector(dx: dir.dx * speed * step, dy: dir.dy * speed * step)
        let moveAction = SKAction.repeatForever(SKAction.move(by: velocity, duration: step))
        bullet.run(moveAction)
    }

    private func spawnLaserBullet(textureName: String, size: CGSize, speed: CGFloat,
                                  origin: CGPoint, dir: CGVector, in scene: SKScene) {
        let bullet = SKSpriteNode(imageNamed: textureName)
        bullet.name = "bullet"
        bullet.size = size
        bullet.position = origin
        bullet.zPosition = 4
        bullet.zRotation = atan2(dir.dy, dir.dx)

        // ⬇️ Mark as laser + set TWO bounces + store per-step velocity
        let step: CGFloat = 0.05
        let v = CGVector(dx: dir.dx * speed * step, dy: dir.dy * speed * step)
        let data = NSMutableDictionary()
        data["isLaser"] = NSNumber(booleanLiteral: true)
        data["bouncesLeft"] = NSNumber(value: 2) // <- was 1, now 2
        data["vx"] = NSNumber(value: Double(v.dx))
        data["vy"] = NSNumber(value: Double(v.dy))
        data["cooldown"] = NSNumber(value: 0.0)
        bullet.userData = data

        scene.addChild(bullet)

        let moveAction = SKAction.repeatForever(SKAction.move(by: v, duration: step))
        bullet.run(moveAction)
    }
}
