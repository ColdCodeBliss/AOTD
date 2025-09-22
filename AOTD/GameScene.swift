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

    // === Scoring ===
    var scoreManager = ScoreManager()
    private var scoreLabel: SKLabelNode!
    private var multLabel: SKLabelNode!

    // MARK: - HUD
    var livesLabel: SKLabelNode!
    var livesHeart: SKSpriteNode!
    var shotgunTimerLabel: SKLabelNode?
    var hmgTimerLabel: SKLabelNode?
    var laserTimerLabel: SKLabelNode?

    // MARK: - Menu / Settings
    var hamburgerNode: SKNode?
    var settingsHost: UIViewController?

    // MARK: - Game Over state
    var isGameOver = false
    var gameOverAlertPresented = false

    // MARK: - Power-ups
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

    // MARK: - Settings persistence
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

    // === Terrain (via TerrainManager) ===
    private var terrainManager = TerrainManager()
    private var terrainBackground: SKSpriteNode?
    private var terrainTilemap: SKNode?

    // MARK: - Scene lifecycle
    override func didMove(to view: SKView) {
        backgroundColor = .brown
        print("GameScene loaded")

        // Scoring delegate
        scoreManager.delegate = self

        // Terrain goes first so it sits behind everything
        let result = terrainManager.applyTerrain(for: levelNumber,
                                                 in: self,
                                                 existingNode: terrainBackground,
                                                 existingTilemap: terrainTilemap)
        terrainBackground = result.bg
        terrainTilemap    = result.tilemap

        setupPlayer()
        setupHUD()
        setupScoreHUD()
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
        positionScoreHUD()

        // Chance-based powerups
        attemptSpawnShotgunForRound()
        attemptSpawnHMGForRound()
        attemptSpawnLaserForRound()   // 10% chance when levelNumber >= 6
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)

        // Keep terrain filling the scene on any size changes
        terrainManager.layout(node: terrainBackground, in: self) // was: relayout / realign...
        CityTilemap.layout(in: self)                             // re-lay out the city tilemap if present

        positionHUD()
        positionHamburger()
        positionShotgunHUD()
        positionHMGHUD()
        positionLaserHUD()
        positionPowerup(hmgPickupNode)
        positionPowerup(shotgunPickupNode)
        positionPowerup(laserPickupNode)
        positionScoreHUD()
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

        // Swap terrain for the new level (background + optional city tilemap)
        let result = terrainManager.applyTerrain(for: levelNumber,
                                                 in: self,
                                                 existingNode: terrainBackground,
                                                 existingTilemap: terrainTilemap)
        terrainBackground = result.bg
        terrainTilemap    = result.tilemap

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

            // reduced-radius circle overlap for zombie→player damage
            if (players.first?.lives ?? 0) > 0, zombieHitsPlayer(zombie, player) {
                let before = player.lives
                player.takeDamage()
                updateHUD()
                if player.lives < before {
                    // lost a life -> reset multiplier
                    scoreManager.resetOnLifeLoss()
                }
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
                    let preHealth = zombie.health
                    zombie.takeDamage(amount: player.currentWeapon.damage)
                    if zombie.health <= 0 && preHealth > 0 {
                        self.scoreManager.awardKill()
                    }

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

    // MARK: - Game Over flow (local wrapper to avoid missing symbol)
    func checkForGameOver() {
        if (players.first?.lives ?? 0) <= 0 {
            // triggerGameOver() is implemented in GameScene+Menu.swift
            triggerGameOver()
        }
    }

    // ============================================================
    // MARK: - Circle-overlap combat helpers (tunable)
    // ============================================================

    private func bulletHitsZombie(_ bullet: SKSpriteNode, _ zombie: Zombie) -> Bool {
        let br = max(bullet.size.width, bullet.size.height) * 0.5 * 0.60
        let zr = zombie.hitRadius
        let dx = bullet.position.x - zombie.position.x
        let dy = bullet.position.y - zombie.position.y
        return (dx*dx + dy*dy) <= (br + zr) * (br + zr)
    }

    private func zombieHitsPlayer(_ zombie: Zombie, _ player: Player) -> Bool {
        let zr = zombie.hitRadius
        let pr: CGFloat = 24
        let dx = player.sprite.position.x - zombie.position.x
        let dy = player.sprite.position.y - zombie.position.y
        return (dx*dx + dy*dy) <= (zr + pr) * (zr + pr)
    }

    // ============================================================
    // MARK: - Score HUD
    // ============================================================

    private func setupScoreHUD() {
        scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        scoreLabel.fontSize = 22
        scoreLabel.fontColor = .white
        scoreLabel.zPosition = 102
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.verticalAlignmentMode   = .center
        addChild(scoreLabel)

        multLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        multLabel.fontSize = 16
        multLabel.fontColor = .white
        multLabel.zPosition = 102
        multLabel.horizontalAlignmentMode = .left
        multLabel.verticalAlignmentMode   = .center
        addChild(multLabel)

        scoreDidChange(to: 0, multiplier: 1)
        positionScoreHUD()
    }

    private func positionScoreHUD() {
        let r = safeFrame()
        let paddingX: CGFloat = 10
        let inlineGap: CGFloat = 8

        var anchorX = r.minX + 12
        var anchorY = r.maxY - 24

        if let ham = hamburgerNode {
            let hamFrame = ham.calculateAccumulatedFrame()
            anchorX = hamFrame.maxX + paddingX
            anchorY = hamFrame.midY
        }

        scoreLabel?.position = CGPoint(x: anchorX, y: anchorY)

        if let s = scoreLabel, let m = multLabel {
            let scoreRight = s.position.x + s.calculateAccumulatedFrame().width
            m.position = CGPoint(x: scoreRight + inlineGap, y: anchorY)
        }
    }

    // MARK: - Graphics application
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

    // === Forwarders for RoundManager (scoring hooks)
    func awardRoundStartPoints(level: Int) { scoreManager.awardRoundStart(level: level) }
    func awardRoundCompletePoints(level: Int) { scoreManager.awardRoundComplete(level: level) }
}

// MARK: - ScoreHUDDelegate
extension GameScene: ScoreHUDDelegate {
    func scoreDidChange(to newScore: Int, multiplier: Int) {
        scoreLabel?.text = "Score: \(newScore)"
        multLabel?.text  = "x\(multiplier)"
        positionScoreHUD()
    }
}

// MARK: - SafeFrameProviding
extension GameScene: SafeFrameProviding {}
