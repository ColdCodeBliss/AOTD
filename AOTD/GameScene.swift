import SpriteKit
import SwiftUI
import UIKit

extension Notification.Name {
    static let AOTDExitToMainMenu = Notification.Name("AOTDExitToMainMenu")
    static let AOTDVolumeChanged  = Notification.Name("AOTDVolumeChanged")
    // AOTDPlayerFiredShot is declared in Player.swift (do not redeclare here)
}

class GameScene: SKScene {
    // MARK: - Core state
    var players: [Player] = []
    var zombies: [Zombie] = []
    var bullets: [SKSpriteNode] = []
    var roundManager: RoundManager?
    var levelNumber: Int = 1

    // MARK: - HUD (owned here, implemented in +HUD)
    var livesLabel: SKLabelNode!
    var livesHeart: SKSpriteNode!
    var shotgunTimerLabel: SKLabelNode?
    var hmgTimerLabel: SKLabelNode?
    var laserTimerLabel: SKLabelNode?

    // MARK: - Menu / Settings (implemented in +Menu)
    var hamburgerNode: SKNode?
    var settingsHost: UIViewController?

    // MARK: - Game Over state
    var isGameOver = false
    var gameOverAlertPresented = false

    // MARK: - Power-ups (implemented in +Powerups)
    var shotgunPickupNode: SKSpriteNode?
    var hmgPickupNode: SKSpriteNode?
    var laserPickupNode: SKSpriteNode?

    var shotgunActive = false
    var shotgunTimeRemaining: TimeInterval = 0
    var roundsSinceShotgunSpawn: Int = 0

    var hmgActive = false
    var hmgTimeRemaining: TimeInterval = 0
    var roundsSinceHMGSpawn: Int = 0

    var laserActive = false
    var laserTimeRemaining: TimeInterval = 0

    // MARK: - Settings persistence (used by +Menu)
    var masterVolume: Float = {
        if UserDefaults.standard.object(forKey: "AOTD.masterVolume") == nil { return 0.8 }
        return UserDefaults.standard.float(forKey: "AOTD.masterVolume")
    }() {
        didSet {
            UserDefaults.standard.set(masterVolume, forKey: "AOTD.masterVolume")
            NotificationCenter.default.post(name: .AOTDVolumeChanged, object: nil, userInfo: ["volume": masterVolume])
        }
    }
    var lowEffectsEnabled: Bool = UserDefaults.standard.bool(forKey: "AOTD.lowEffects") {
        didSet { UserDefaults.standard.set(lowEffectsEnabled, forKey: "AOTD.lowEffects"); applyGraphicsToManagersAndView() }
    }
    var fps30CapEnabled: Bool = UserDefaults.standard.bool(forKey: "AOTD.fps30Cap") {
        didSet { UserDefaults.standard.set(fps30CapEnabled, forKey: "AOTD.fps30Cap"); applyGraphicsToManagersAndView() }
    }
    var shadowsDisabled: Bool = UserDefaults.standard.bool(forKey: "AOTD.disableShadows") {
        didSet { UserDefaults.standard.set(shadowsDisabled, forKey: "AOTD.disableShadows"); applyGraphicsToManagersAndView() }
    }

    // MARK: - Scene lifecycle
    override func didMove(to view: SKView) {
        backgroundColor = .brown
        print("GameScene loaded")

        setupPlayer()
        setupHUD()
        addHamburger()

        NotificationCenter.default.addObserver(self, selector: #selector(onPlayerFiredShot(_:)), name: .AOTDPlayerFiredShot, object: nil)

        if let levels = LevelLoader.loadLevels() {
            let rm = RoundManager(levelData: levels)
            rm.lowEffectsEnabled = lowEffectsEnabled
            rm.spawnFPS30CapHint = fps30CapEnabled
            rm.shadowsDisabled = shadowsDisabled
            roundManager = rm
            roundManager?.startRound(in: self)
        }

        applyGraphicsToManagersAndView()
        positionHUD()
        positionHamburger()

        // Chance-based powerups
        attemptSpawnShotgunForRound()
        attemptSpawnHMGForRound()
        attemptSpawnLaserForRound()   // 10% chance when levelNumber >= 6
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        positionHUD()
        positionHamburger()
        positionShotgunHUD()
        positionHMGHUD()
        positionLaserHUD()
        positionPowerup(hmgPickupNode)
        positionPowerup(shotgunPickupNode)
        positionPowerup(laserPickupNode)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Player Setup
    func setupPlayer() {
        guard let viewSize = view?.bounds.size else { return }
        let playerSprite = SKSpriteNode(imageNamed: "player_1")
        playerSprite.size = CGSize(width: 60, height: 60)
        playerSprite.position = CGPoint(x: viewSize.width/2, y: viewSize.height/2)
        let weapon = Weapon(type: .machineGun)
        let player = Player(sprite: playerSprite, weapon: weapon)
        players = [player]
        addChild(player.sprite)

        let bob = SKAction.sequence([SKAction.moveBy(x: 0, y: 5, duration: 0.5),
                                     SKAction.moveBy(x: 0, y: -5, duration: 0.5)])
        player.sprite.run(SKAction.repeatForever(bob))
    }

    // MARK: - Level flow
    func startCountdownAndLevel(spawnCallback: @escaping () -> Void) {
        var count = 3
        let countdownLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        countdownLabel.fontSize = 80
        countdownLabel.fontColor = .white
        countdownLabel.position = CGPoint(x: size.width/2, y: size.height/2)
        countdownLabel.zPosition = 10
        addChild(countdownLabel)

        let countdownAction = SKAction.repeat(SKAction.sequence([
            SKAction.run { countdownLabel.text = "\(count)" },
            SKAction.wait(forDuration: 1.0),
            SKAction.run { count -= 1 }
        ]), count: 3)

        run(countdownAction) { [weak countdownLabel] in
            countdownLabel?.removeFromParent()
            spawnCallback()
        }
    }

    func spawnZombie(level: Level) {
        let side = Int.random(in: 0..<4)
        var position = CGPoint.zero
        switch side {
        case 0: position = CGPoint(x: CGFloat.random(in: 0..<size.width), y: size.height + 50)
        case 1: position = CGPoint(x: CGFloat.random(in: 0..<size.width), y: -50)
        case 2: position = CGPoint(x: -50, y: CGFloat.random(in: 0..<size.height))
        case 3: position = CGPoint(x: size.width + 50, y: CGFloat.random(in: 0..<size.height))
        default: break
        }

        let zombie = Zombie(texture: SKTexture(imageNamed: "zombie"),
                            color: .clear,
                            size: CGSize(width: 50, height: 50))
        zombie.position = position
        zombie.health = max(1, levelNumber)
        zombie.moveSpeed = 1.5
        zombie.zPosition = 1
        addChild(zombie)
        zombies.append(zombie)

        let pulse = SKAction.sequence([SKAction.scale(to: 1.2, duration: 0.5),
                                       SKAction.scale(to: 1.0, duration: 0.5)])
        zombie.run(SKAction.repeatForever(pulse))
    }

    func proceedToNextLevel() {
        levelNumber += 1
        roundManager?.startRound(in: self)

        attemptSpawnShotgunForRound()
        attemptSpawnHMGForRound()
        attemptSpawnLaserForRound()   // 10% chance when levelNumber >= 6
    }

    // MARK: - Update loop
    override func update(_ currentTime: TimeInterval) {
        guard let player = players.first else { return }
        if isGameOver { return }

        // Remove dead zombies & move them
        zombies = zombies.filter { zombie in
            if zombie.health <= 0 {
                zombie.removeFromParent()
                return false
            }
            zombie.update(playerPosition: player.sprite.position)

            // ⬇️ Use reduced-radius circle overlap for zombie→player damage
            if (players.first?.lives ?? 0) > 0, zombieHitsPlayer(zombie, player) {
                player.takeDamage()
                updateHUD()
                checkForGameOver()
            }
            return true
        }

        // Bullet collisions & ricochets
        enumerateChildNodes(withName: "bullet") { node, _ in
            guard let bullet = node as? SKSpriteNode else { return }
            let isLaser = (bullet.userData?["isLaser"] as? NSNumber)?.boolValue ?? false

            // Hit zombies using reduced-radius circle overlap
            for zombie in self.zombies {
                if self.bulletHitsZombie(bullet, zombie) {
                    zombie.takeDamage(amount: player.currentWeapon.damage)
                    if isLaser {
                        if self.ricochetLaserBulletOffZombie(bullet, zombieCenter: zombie.position) {
                            break
                        } else {
                            bullet.removeAllActions()
                            bullet.removeFromParent()
                            break
                        }
                    } else {
                        bullet.removeAllActions()
                        bullet.removeFromParent()
                        break
                    }
                }
            }
        }

        // Laser bullets: bounce off screen bounds
        enumerateChildNodes(withName: "bullet") { node, _ in
            guard let b = node as? SKSpriteNode else { return }
            let isLaser = (b.userData?["isLaser"] as? NSNumber)?.boolValue ?? false
            if isLaser {
                self.handleLaserBulletBounds(b)
            }
        }

        // Power-up pickups
        if let pickup = shotgunPickupNode, pickup.parent != nil, playerIsOverlapping(pickup) { handleShotgunPickup() }
        if let pickup = hmgPickupNode, pickup.parent != nil, playerIsOverlapping(pickup) { handleHMGPickup() }
        if let pickup = laserPickupNode, pickup.parent != nil, playerIsOverlapping(pickup) { handleLaserPickup() }

        updateShotgunHUD()
        updateHMGHUD()
        updateLaserHUD()
        updateHUD()

        // Round completion
        if zombies.isEmpty,
           roundManager?.zombiesSpawnedThisRound ?? 0 >= roundManager?.maxZombiesThisRound ?? 0 {
            roundManager?.levelCompleted()
        }
    }

    // MARK: - Game Over flow (implemented in +Menu)
    func checkForGameOver() {
        if (players.first?.lives ?? 0) <= 0 { triggerGameOver() }
    }

    // MARK: - Graphics application (used by +Menu)
    func applyGraphicsToManagersAndView() {
        if let skv = view {
            skv.preferredFramesPerSecond = fps30CapEnabled ? 30 : 60
        }
        if shadowsDisabled {
            enumerateChildNodes(withName: "//") { node, _ in
                node.children.compactMap { $0 as? SKLightNode }.forEach { $0.isEnabled = false }
            }
        }
        roundManager?.lowEffectsEnabled = lowEffectsEnabled
        roundManager?.spawnFPS30CapHint = fps30CapEnabled
        roundManager?.shadowsDisabled = shadowsDisabled
    }

    // ============================================================
    // MARK: - Circle-overlap combat helpers (tunable)
    // ============================================================

    /// Bullet→Zombie: compare distance vs (reduced bullet radius + scaled zombie radius)
    private func bulletHitsZombie(_ bullet: SKSpriteNode, _ zombie: Zombie) -> Bool {
        let br = max(bullet.size.width, bullet.size.height) * 0.5 * 0.60   // shrink bullet radius a bit
        let zr = zombie.hitRadius                                          // scaled by Zombie.hitRadiusScale
        let dx = bullet.position.x - zombie.position.x
        let dy = bullet.position.y - zombie.position.y
        return (dx*dx + dy*dy) <= (br + zr) * (br + zr)
    }

    /// Zombie→Player: compare distance vs (scaled zombie radius + player radius)
    private func zombieHitsPlayer(_ zombie: Zombie, _ player: Player) -> Bool {
        let zr = zombie.hitRadius
        let pr: CGFloat = 24                                               // player effective radius (tweak)
        let dx = player.sprite.position.x - zombie.position.x
        let dy = player.sprite.position.y - zombie.position.y
        return (dx*dx + dy*dy) <= (zr + pr) * (zr + pr)
    }
}
