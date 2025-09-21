import SpriteKit

extension GameScene {
    // Store & read continuous velocity for laser bullets
    func getLaserVelocity(_ bullet: SKSpriteNode) -> CGVector {
        let vx = (bullet.userData?["vx"] as? NSNumber)?.doubleValue ?? 0.0
        let vy = (bullet.userData?["vy"] as? NSNumber)?.doubleValue ?? 0.0
        return CGVector(dx: vx, dy: vy)
    }

    func setLaserVelocity(_ bullet: SKSpriteNode, v: CGVector) {
        if bullet.userData == nil { bullet.userData = NSMutableDictionary() }
        bullet.userData?["vx"] = NSNumber(value: Double(v.dx))
        bullet.userData?["vy"] = NSNumber(value: Double(v.dy))

        bullet.removeAllActions()
        let step: CGFloat = 0.05
        let move = SKAction.repeatForever(SKAction.move(by: v, duration: step))
        bullet.run(move)
        bullet.zRotation = atan2(v.dy, v.dx)
    }

    /// Decrement remaining bounces and return the new value.
    func decBounce(_ bullet: SKSpriteNode) -> Int {
        if bullet.userData == nil { bullet.userData = NSMutableDictionary() }
        let left = max(0, (bullet.userData?["bouncesLeft"] as? NSNumber)?.intValue ?? 0)
        let newVal = max(0, left - 1)
        bullet.userData?["bouncesLeft"] = NSNumber(value: newVal)
        return newVal
    }

    /// Reflect a laser bullet off a zombie using a simple normal reflection.
    func ricochetLaserBulletOffZombie(_ bullet: SKSpriteNode, zombieCenter: CGPoint) -> Bool {
        let left = (bullet.userData?["bouncesLeft"] as? NSNumber)?.intValue ?? 0
        guard left > 0 else { return false }

        let v = getLaserVelocity(bullet)
        var n = CGVector(dx: bullet.position.x - zombieCenter.x,
                         dy: bullet.position.y - zombieCenter.y)
        let nlen = max(0.0001, sqrt(n.dx*n.dx + n.dy*n.dy))
        n = CGVector(dx: n.dx / nlen, dy: n.dy / nlen)

        let dot = v.dx * n.dx + v.dy * n.dy
        let vPrime = CGVector(dx: v.dx - 2 * dot * n.dx,
                              dy: v.dy - 2 * dot * n.dy)

        setLaserVelocity(bullet, v: vPrime)
        _ = decBounce(bullet)
        return true
    }

    /// Bounce laser bullets off the screen edges.
    func handleLaserBulletBounds(_ bullet: SKSpriteNode) {
        let isLaser = (bullet.userData?["isLaser"] as? NSNumber)?.boolValue ?? false
        guard isLaser else { return }
        let left = (bullet.userData?["bouncesLeft"] as? NSNumber)?.intValue ?? 0

        let r = self.safeFrame()
        let margin: CGFloat = 4

        var bounced = false
        var v = getLaserVelocity(bullet)

        if bullet.position.x <= r.minX + margin {
            if left > 0 { v.dx = abs(v.dx); bounced = true }
            else { bullet.removeFromParent(); return }
        } else if bullet.position.x >= r.maxX - margin {
            if left > 0 { v.dx = -abs(v.dx); bounced = true }
            else { bullet.removeFromParent(); return }
        }

        if bullet.position.y <= r.minY + margin {
            if left > 0 { v.dy = abs(v.dy); bounced = true }
            else { bullet.removeFromParent(); return }
        } else if bullet.position.y >= r.maxY - margin {
            if left > 0 { v.dy = -abs(v.dy); bounced = true }
            else { bullet.removeFromParent(); return }
        }

        if bounced {
            setLaserVelocity(bullet, v: v)
            _ = decBounce(bullet)
            // clamp inside
            bullet.position.x = min(max(bullet.position.x, r.minX + margin), r.maxX - margin)
            bullet.position.y = min(max(bullet.position.y, r.minY + margin), r.maxY - margin)
        }
    }
}
