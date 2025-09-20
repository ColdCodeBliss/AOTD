//
//  GameScene+Powerups.swift
//  AOTD
//
//  Created by Ryan Bliss on 9/19/25.
//

import SpriteKit

extension GameScene {
    // MARK: Chance-based spawns per round
    func attemptSpawnShotgunForRound() {
        guard shotgunPickupNode == nil else { return }
        let roll = Int.random(in: 1...100)
        var shouldSpawn = (roll <= 10)
        roundsSinceShotgunSpawn += 1
        if roundsSinceShotgunSpawn >= 3 { shouldSpawn = true }
        if shouldSpawn { spawnShotgunPickup(); roundsSinceShotgunSpawn = 0 }
    }

    func attemptSpawnHMGForRound() {
        guard hmgPickupNode == nil else { return }
        let roll = Int.random(in: 1...100)
        var shouldSpawn = (roll <= 10)
        roundsSinceHMGSpawn += 1
        if roundsSinceHMGSpawn >= 5 { shouldSpawn = true }
        if shouldSpawn { spawnHMGPickup(); roundsSinceHMGSpawn = 0 }
    }

    /// 10% chance to spawn the laser gun on any round **after round 5**.
    func attemptSpawnLaserForRound() {
        guard levelNumber >= 6 else { return }      // rounds > 5
        guard laserPickupNode == nil else { return }
        let roll = Int.random(in: 1...100)
        if roll <= 10 { spawnLaserPickup() }
    }

    // MARK: Spawn positions
    func spawnShotgunPickup() {
        guard shotgunPickupNode == nil, let player = players.first else { return }
        let node = SKSpriteNode(imageNamed: "shotgun")
        node.name = "powerup_shotgun"
        node.zPosition = 50
        node.size = CGSize(width: 56, height: 20)

        let r = self.safeFrame()
        let x = min(max(r.minX + 80, player.sprite.position.x + 100), r.maxX - 60)
        let y = min(max(r.minY + 80, player.sprite.position.y), r.maxY - 60)
        node.position = CGPoint(x: x, y: y)
        shotgunPickupNode = node
        addChild(node)

        attachDespawnTimerAndFlashing(to: node, kind: .shotgun)
    }

    func spawnHMGPickup() {
        guard hmgPickupNode == nil, let player = players.first else { return }
        let node = SKSpriteNode(imageNamed: "heavyMachineGun")
        node.name = "powerup_hmg"
        node.zPosition = 50
        node.size = CGSize(width: 64, height: 24)

        let r = self.safeFrame()
        let x = min(max(r.minX + 80, player.sprite.position.x + 100), r.maxX - 60)
        let y = min(max(r.minY + 80, player.sprite.position.y - 40), r.maxY - 60)
        node.position = CGPoint(x: x, y: y)
        hmgPickupNode = node
        addChild(node)

        attachDespawnTimerAndFlashing(to: node, kind: .hmg)
    }

    private func spawnLaserPickup() {
        guard laserPickupNode == nil, let player = players.first else { return }
        let node = SKSpriteNode(imageNamed: "lasergun")
        node.name = "powerup_laser"
        node.zPosition = 50
        node.size = CGSize(width: 60, height: 18)

        let r = self.safeFrame()
        let x = min(max(r.minX + 80, player.sprite.position.x + 120), r.maxX - 60)
        let y = min(max(r.minY + 80, player.sprite.position.y + 40), r.maxY - 60)
        node.position = CGPoint(x: x, y: y)
        laserPickupNode = node
        addChild(node)

        attachDespawnTimerAndFlashing(to: node, kind: .laser)
    }

    func positionPowerup(_ node: SKSpriteNode?) {
        guard let node = node else { return }
        let r = self.safeFrame()
        let clampedX = min(max(r.minX + 40, node.position.x), r.maxX - 40)
        let clampedY = min(max(r.minY + 40, node.position.y), r.maxY - 40)
        node.position = CGPoint(x: clampedX, y: clampedY)
    }

    // MARK: Pickups
    func handleShotgunPickup() {
        guard let player = players.first else { return }
        shotgunPickupNode?.removeAllActions()
        shotgunPickupNode?.removeFromParent()
        shotgunPickupNode = nil

        let shotgun = Weapon(type: .shotgun)
        player.setWeapon(shotgun)

        shotgunActive = true
        shotgunTimeRemaining = 10.0
        showShotgunHUD()
        updateShotgunHUD()
    }

    func handleHMGPickup() {
        guard let player = players.first else { return }
        hmgPickupNode?.removeAllActions()
        hmgPickupNode?.removeFromParent()
        hmgPickupNode = nil

        let hmg = Weapon(type: .heavyMachineGun)
        player.setWeapon(hmg)

        hmgActive = true
        hmgTimeRemaining = 12.0
        showHMGHUD()
        updateHMGHUD()
    }

    func handleLaserPickup() {
        guard let player = players.first else { return }
        laserPickupNode?.removeAllActions()
        laserPickupNode?.removeFromParent()
        laserPickupNode = nil

        let laser = Weapon(type: .laserGun)
        player.setWeapon(laser)

        laserActive = true
        laserTimeRemaining = 7.0
        showLaserHUD()
        updateLaserHUD()
    }

    // MARK: Firing-time timers
    @objc func onPlayerFiredShot(_ note: Notification) {
        guard let dt = note.userInfo?["fireInterval"] as? TimeInterval else { return }
        if shotgunActive {
            shotgunTimeRemaining -= dt
            if shotgunTimeRemaining <= 0 { endShotgunPowerup() } else { updateShotgunHUD() }
        }
        if hmgActive {
            hmgTimeRemaining -= dt
            if hmgTimeRemaining <= 0 { endHMGPowerup() } else { updateHMGHUD() }
        }
        if laserActive {
            laserTimeRemaining -= dt
            if laserTimeRemaining <= 0 { endLaserPowerup() } else { updateLaserHUD() }
        }
    }

    func endShotgunPowerup() {
        guard shotgunActive, let player = players.first else { return }
        shotgunActive = false
        shotgunTimeRemaining = 0
        player.setWeapon(Weapon(type: .machineGun))
        removeShotgunHUD()
    }

    func endHMGPowerup() {
        guard hmgActive, let player = players.first else { return }
        hmgActive = false
        hmgTimeRemaining = 0
        player.setWeapon(Weapon(type: .machineGun))
        removeHMGHUD()
    }

    func endLaserPowerup() {
        guard laserActive, let player = players.first else { return }
        laserActive = false
        laserTimeRemaining = 0
        player.setWeapon(Weapon(type: .machineGun))
        removeLaserHUD()
    }

    // Overlap test
    func playerIsOverlapping(_ node: SKNode, playerRadius: CGFloat = 28) -> Bool {
        guard let player = players.first else { return false }
        let p = player.sprite.position
        let n = node.position
        let dx = p.x - n.x
        let dy = p.y - n.y
        let dist2 = dx*dx + dy*dy
        let nodeRadius: CGFloat = (node as? SKSpriteNode).map { max($0.size.width, $0.size.height) * 0.5 } ?? 24
        let r = playerRadius + nodeRadius
        return dist2 <= r*r
    }

    // Despawn + flashing
    func attachDespawnTimerAndFlashing(to node: SKSpriteNode, kind: PowerupKind, lifetime: TimeInterval = 15.0) {
        let now = CACurrentMediaTime()
        let despawnAt = now + lifetime
        let data = node.userData ?? NSMutableDictionary()
        data["despawnAt"] = NSNumber(value: despawnAt)
        data["lastToggle"] = NSNumber(value: now)
        data["flashOn"] = NSNumber(booleanLiteral: true)
        node.userData = data

        node.alpha = 1.0

        let tick = SKAction.repeatForever(.sequence([
            .wait(forDuration: 0.05),
            .run { [weak self, weak node] in
                guard let self = self, let n = node, n.parent != nil else { return }
                let now = CACurrentMediaTime()
                let end = (n.userData?["despawnAt"] as? NSNumber)?.doubleValue ?? now
                var last = (n.userData?["lastToggle"] as? NSNumber)?.doubleValue ?? now
                var on = (n.userData?["flashOn"] as? NSNumber)?.boolValue ?? true

                let remaining = end - now
                if remaining <= 0 {
                    n.removeAllActions()
                    n.removeFromParent()
                    switch kind {
                    case .shotgun: if self.shotgunPickupNode === n { self.shotgunPickupNode = nil }
                    case .hmg:     if self.hmgPickupNode === n     { self.hmgPickupNode = nil }
                    case .laser:   if self.laserPickupNode === n   { self.laserPickupNode = nil }
                    }
                    return
                }

                let interval: Double
                if remaining > 10 { interval = 0.60 }
                else if remaining > 5 { interval = 0.30 }
                else if remaining > 2 { interval = 0.15 }
                else { interval = 0.08 }

                if now - last >= interval {
                    on.toggle()
                    n.alpha = on ? 1.0 : 0.25
                    last = now
                    n.userData?["lastToggle"] = NSNumber(value: last)
                    n.userData?["flashOn"] = NSNumber(booleanLiteral: on)
                }
            }
        ]))
        node.run(tick, withKey: "powerupLifetime")
    }

    // Convenience for restart
    func resetAllPowerupsAndHUD() {
        // clear HUD first
        removeShotgunHUD()
        removeHMGHUD()
        removeLaserHUD()

        // reset state & timers
        shotgunActive = false
        shotgunTimeRemaining = 0
        roundsSinceShotgunSpawn = 0

        hmgActive = false
        hmgTimeRemaining = 0
        roundsSinceHMGSpawn = 0

        laserActive = false
        laserTimeRemaining = 0

        // remove any existing pickups
        shotgunPickupNode?.removeAllActions()
        shotgunPickupNode?.removeFromParent()
        shotgunPickupNode = nil

        hmgPickupNode?.removeAllActions()
        hmgPickupNode?.removeFromParent()
        hmgPickupNode = nil

        laserPickupNode?.removeAllActions()
        laserPickupNode?.removeFromParent()
        laserPickupNode = nil
    }
}
