import SpriteKit
import CoreGraphics

enum WeaponType {
    case machineGun
    case heavyMachineGun
    case laserGun
    case shotgun
}

class Weapon {
    let type: WeaponType

    // Core tuning
    let damage: Int
    let fireRate: TimeInterval
    let projectileSpeed: CGFloat

    // Shotgun extras
    let pelletCount: Int
    let spreadDegrees: CGFloat

    // Visual sizing
    let projectileSize: CGSize

    // Suggested muzzle offsets
    let muzzleForwardOffset: CGFloat
    let muzzleLateralOffset: CGFloat

    // 🔧 If your bullet art points UP (+Y), keep this at -π/2 to rotate it to RIGHT (+X).
    //    If your art already points RIGHT, set this to 0.
    private let orientationCorrection: CGFloat = -.pi / 2

    init(type: WeaponType) {
        self.type = type
        switch type {
        case .machineGun:
            damage = 1; fireRate = 0.08; projectileSpeed = 1050
            pelletCount = 1; spreadDegrees = 0
            projectileSize = CGSize(width: 12, height: 12)
            muzzleForwardOffset = 0; muzzleLateralOffset = 0

        case .heavyMachineGun:
            damage = 2; fireRate = 0.14; projectileSpeed = 1000
            pelletCount = 1; spreadDegrees = 3
            projectileSize = CGSize(width: 16, height: 16)
            muzzleForwardOffset = 4; muzzleLateralOffset = 0

        case .laserGun:
            damage = 1; fireRate = 0.05; projectileSpeed = 1400
            pelletCount = 1; spreadDegrees = 0
            projectileSize = CGSize(width: 34, height: 6) // skinny dart
            muzzleForwardOffset = 6; muzzleLateralOffset = 0

        case .shotgun:
            damage = 1; fireRate = 0.45; projectileSpeed = 1000
            pelletCount = 7; spreadDegrees = 22
            projectileSize = CGSize(width: 9, height: 9)
            muzzleForwardOffset = 2; muzzleLateralOffset = 0
        }
    }

    func fire(from origin: CGPoint, direction: CGVector, in scene: SKScene) {
        let dir = normalize(direction)
        guard dir.dx != 0 || dir.dy != 0 else { return }

        switch type {
        case .machineGun:
            let node = makeBulletNode(color: .white)
            spawn(node: node, from: origin, dir: dir, in: scene)

        case .heavyMachineGun:
            let node = makeBulletNode(color: .orange)
            let spreadRad = degreesToRadians(CGFloat.random(in: -spreadDegrees...spreadDegrees))
            let d = rotate(dir, by: spreadRad)
            spawn(node: node, from: origin, dir: d, in: scene)

        case .laserGun:
            let node = SKSpriteNode(color: .cyan, size: projectileSize)
            node.name = "bullet"
            node.zPosition = 20
            node.anchorPoint = CGPoint(x: 0.1, y: 0.5)
            spawn(node: node, from: origin, dir: dir, in: scene)

        case .shotgun:
            let step = spreadDegrees / CGFloat(max(1, pelletCount - 1))
            let start = -spreadDegrees * 0.5
            for i in 0..<pelletCount {
                let angleDeg = start + CGFloat(i) * step + CGFloat.random(in: -1.0...1.0)
                let d = rotate(dir, by: degreesToRadians(angleDeg))
                let pellet = makeBulletNode(color: .white.withAlphaComponent(0.95), sizeOverride: projectileSize)
                spawn(node: pellet, from: origin, dir: d, in: scene, customSpeed: projectileSpeed * CGFloat.random(in: 0.9...1.05))
            }
        }
    }

    // MARK: - Helpers

    private func makeBulletNode(color: UIColor, sizeOverride: CGSize? = nil) -> SKSpriteNode {
        let node = SKSpriteNode(imageNamed: "bullet")
        node.colorBlendFactor = 1.0
        node.color = color
        node.size = sizeOverride ?? projectileSize
        node.name = "bullet"
        node.zPosition = 20
        node.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        node.texture?.filteringMode = .nearest
        return node
    }

    private func spawn(node: SKSpriteNode,
                       from origin: CGPoint,
                       dir: CGVector,
                       in scene: SKScene,
                       customSpeed: CGFloat? = nil)
    {
        node.position = origin

        // ✅ Apply orientation correction so the sprite "faces" along +X.
        let aim = atan2(dir.dy, dir.dx) + orientationCorrection
        node.zRotation = aim

        scene.addChild(node)

        let speed = customSpeed ?? projectileSpeed
        let maxDim = max(scene.size.width, scene.size.height)
        let travel: CGFloat = maxDim * 1.8
        let end = CGPoint(x: origin.x + dir.dx * travel, y: origin.y + dir.dy * travel)
        let duration = TimeInterval(travel / speed)

        if projectileSize.width >= 12 || projectileSize.height >= 12 {
            node.setScale(0.9)
            node.run(.sequence([
                .scale(to: 1.0, duration: 0.05),
                .group([
                    .move(to: end, duration: duration),
                    .fadeAlpha(to: 0.92, duration: 0.08)
                ]),
                .removeFromParent()
            ]))
        } else {
            node.run(.sequence([.move(to: end, duration: duration), .removeFromParent()]))
        }
    }

    private func normalize(_ v: CGVector) -> CGVector {
        let m = sqrt(v.dx * v.dx + v.dy * v.dy)
        if m == 0 { return .zero }
        return CGVector(dx: v.dx / m, dy: v.dy / m)
    }

    private func rotate(_ v: CGVector, by angle: CGFloat) -> CGVector {
        let c = cos(angle), s = sin(angle)
        return CGVector(dx: v.dx * c - v.dy * s, dy: v.dx * s + v.dy * c)
    }

    private func degreesToRadians(_ deg: CGFloat) -> CGFloat { deg * .pi / 180 }
}
