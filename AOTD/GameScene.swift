import SpriteKit
import SwiftUI
import UIKit

extension Notification.Name {
    static let AOTDExitToMainMenu = Notification.Name("AOTDExitToMainMenu")
    static let AOTDVolumeChanged  = Notification.Name("AOTDVolumeChanged")
    // AOTDPlayerFiredShot is declared in Player.swift (do not redeclare here)
}

class GameScene: SKScene {
    var players: [Player] = []
    var zombies: [Zombie] = []
    var bullets: [SKSpriteNode] = []
    var roundManager: RoundManager?

    var levelNumber: Int = 1

    // MARK: - HUD
    var livesLabel: SKLabelNode!
    var livesHeart: SKSpriteNode!
    private var shotgunTimerLabel: SKLabelNode?
    private var hmgTimerLabel: SKLabelNode?
    private var laserTimerLabel: SKLabelNode?

    // MARK: - Menu/Settings
    private var hamburgerNode: SKNode?
    private var settingsHost: UIViewController?

    // MARK: - Game Over state
    private var isGameOver = false
    private var gameOverAlertPresented = false

    // MARK: - Power-ups
    private var shotgunPickupNode: SKSpriteNode?
    private var hmgPickupNode: SKSpriteNode?
    private var laserPickupNode: SKSpriteNode?

    // Shotgun (firing-time power-up)
    private var shotgunActive = false
    private var shotgunTimeRemaining: TimeInterval = 0
    private var roundsSinceShotgunSpawn: Int = 0   // 10% chance, guaranteed every 3 rounds

    // HMG (firing-time power-up)
    private var hmgActive = false
    private var hmgTimeRemaining: TimeInterval = 0
    private var roundsSinceHMGSpawn: Int = 0       // 10% chance, guaranteed every 5 rounds

    // Laser (firing-time power-up)
    private var laserActive = false
    private var laserTimeRemaining: TimeInterval = 0  // 7s firing-only

    // persisted settings
    private var masterVolume: Float = {
        if UserDefaults.standard.object(forKey: "AOTD.masterVolume") == nil { return 0.8 }
        return UserDefaults.standard.float(forKey: "AOTD.masterVolume")
    }() {
        didSet {
            UserDefaults.standard.set(masterVolume, forKey: "AOTD.masterVolume")
            NotificationCenter.default.post(name: .AOTDVolumeChanged, object: nil, userInfo: ["volume": masterVolume])
        }
    }
    private var lowEffectsEnabled: Bool = UserDefaults.standard.bool(forKey: "AOTD.lowEffects") {
        didSet { UserDefaults.standard.set(lowEffectsEnabled, forKey: "AOTD.lowEffects"); applyGraphicsToManagersAndView() }
    }
    private var fps30CapEnabled: Bool = UserDefaults.standard.bool(forKey: "AOTD.fps30Cap") {
        didSet { UserDefaults.standard.set(fps30CapEnabled, forKey: "AOTD.fps30Cap"); applyGraphicsToManagersAndView() }
    }
    private var shadowsDisabled: Bool = UserDefaults.standard.bool(forKey: "AOTD.disableShadows") {
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

        // Round 1 evaluation for chance-based powerups
        attemptSpawnShotgunForRound()
        attemptSpawnHMGForRound()

        // Laser test: spawn at start of Round 1
        spawnLaserPickupAtRound1()
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

    // MARK: - HUD Setup
    func setupHUD() {
        livesHeart = SKSpriteNode(imageNamed: "heart")
        livesHeart.size = CGSize(width: 30, height: 30)
        livesHeart.zPosition = 100
        addChild(livesHeart)

        livesLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        livesLabel.fontSize = 24
        livesLabel.fontColor = .white
        livesLabel.horizontalAlignmentMode = .left
        livesLabel.verticalAlignmentMode = .center
        livesLabel.zPosition = 100
        livesLabel.text = "\(players.first?.lives ?? 3)"
        addChild(livesLabel)

        // Shotgun timer HUD
        let sLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        sLabel.fontSize = 18
        sLabel.fontColor = .yellow
        sLabel.zPosition = 101
        sLabel.text = ""
        sLabel.isHidden = true
        shotgunTimerLabel = sLabel
        addChild(sLabel)

        // HMG timer HUD
        let hLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        hLabel.fontSize = 18
        hLabel.fontColor = .orange
        hLabel.zPosition = 101
        hLabel.text = ""
        hLabel.isHidden = true
        hmgTimerLabel = hLabel
        addChild(hLabel)

        // Laser timer HUD
        let lLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        lLabel.fontSize = 18
        lLabel.fontColor = SKColor(cgColor: CGColor(red: 0.4, green: 0.95, blue: 1.0, alpha: 1.0)) // teal/cyan
        lLabel.zPosition = 101
        lLabel.text = ""
        lLabel.isHidden = true
        laserTimerLabel = lLabel
        addChild(lLabel)

        positionHUD()
        positionShotgunHUD()
        positionHMGHUD()
        positionLaserHUD()
    }

    // Safe-area helpers
    private func safeAreaInsets() -> UIEdgeInsets { view?.window?.safeAreaInsets ?? .zero }
    private func safeFrame() -> CGRect {
        let sz = view?.bounds.size ?? size
        return CGRect(origin: .zero, size: sz).inset(by: safeAreaInsets())
    }

    func positionHUD() {
        guard let heart = livesHeart, let label = livesLabel else { return }
        let r = safeFrame()
        let padding: CGFloat = 12

        let heartHalfW = heart.size.width * 0.5
        let heartHalfH = heart.size.height * 0.5
        heart.position = CGPoint(x: r.maxX - padding - heartHalfW, y: r.maxY - padding - heartHalfH)
        label.position = CGPoint(x: heart.position.x + 25, y: heart.position.y - 1)
    }

    private func positionShotgunHUD() {
        guard let lbl = shotgunTimerLabel else { return }
        let r = safeFrame()
        lbl.position = CGPoint(x: r.midX, y: r.maxY - 24)
    }

    private func positionHMGHUD() {
        guard let lbl = hmgTimerLabel else { return }
        let r = safeFrame()
        lbl.position = CGPoint(x: r.midX, y: r.maxY - 44) // just below shotgun label
    }

    private func positionLaserHUD() {
        guard let lbl = laserTimerLabel else { return }
        let r = safeFrame()
        lbl.position = CGPoint(x: r.midX, y: r.maxY - 64) // below HMG label
    }

    func updateHUD() {
        let lives = max(0, players.first?.lives ?? 0)
        livesLabel?.text = "\(lives)"
    }

    // MARK: - Countdown and Level Start (called by RoundManager)
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

    // MARK: - Spawn individual zombie (called by RoundManager)
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

    // MARK: - Proceed to next level (called by RoundManager)
    func proceedToNextLevel() {
        levelNumber += 1
        roundManager?.startRound(in: self)

        // Per-round chance-based spawns
        attemptSpawnShotgunForRound()
        attemptSpawnHMGForRound()

        // Laser is test-only at Round 1, so no per-round spawn here
    }

    // MARK: - Update loop
    override func update(_ currentTime: TimeInterval) {
        guard let player = players.first else { return }
        if isGameOver { return }

        // Remove dead zombies and update movement
        zombies = zombies.filter { zombie in
            if zombie.health <= 0 {
                zombie.removeFromParent()
                return false
            }
            zombie.update(playerPosition: player.sprite.position)
            if (players.first?.lives ?? 0) > 0, zombie.frame.intersects(player.sprite.frame) {
                player.takeDamage()
                updateHUD()
                checkForGameOver()
            }
            return true
        }

        // Bullet collisions
        enumerateChildNodes(withName: "bullet") { node, _ in
            guard let bullet = node as? SKSpriteNode else { return }
            for zombie in self.zombies {
                if bullet.frame.intersects(zombie.frame) {
                    zombie.takeDamage(amount: player.currentWeapon.damage)
                    bullet.removeFromParent()
                }
            }
        }

        // Power-up pickups
        if let pickup = shotgunPickupNode, pickup.parent != nil, pickup.frame.intersects(player.sprite.frame) {
            handleShotgunPickup()
        }
        if let pickup = hmgPickupNode, pickup.parent != nil, pickup.frame.intersects(player.sprite.frame) {
            handleHMGPickup()
        }
        if let pickup = laserPickupNode, pickup.parent != nil, pickup.frame.intersects(player.sprite.frame) {
            handleLaserPickup()
        }

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

    private func checkForGameOver() {
        if (players.first?.lives ?? 0) <= 0 {
            triggerGameOver()
        }
    }

    private func triggerGameOver() {
        guard !gameOverAlertPresented else { return }
        isGameOver = true
        gameOverAlertPresented = true

        roundManager?.spawnTimer?.invalidate()
        roundManager?.spawnTimer = nil
        isPaused = true

        let alert = UIAlertController(
            title: "You were overrun and are out of lives!",
            message: "Try again?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: { _ in
            NotificationCenter.default.post(name: .AOTDExitToMainMenu, object: nil)
        }))
        alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { _ in
            self.restartSinglePlayer()
        }))

        topViewController()?.present(alert, animated: true, completion: nil)
    }

    private func restartSinglePlayer() {
        removeAllActions()

        enumerateChildNodes(withName: "bullet") { node, _ in node.removeFromParent() }
        for z in zombies { z.removeFromParent() }
        zombies.removeAll()

        // Reset power-ups & HUD
        removeShotgunHUD(); shotgunActive = false; shotgunTimeRemaining = 0; roundsSinceShotgunSpawn = 0
        removeHMGHUD();     hmgActive = false;     hmgTimeRemaining = 0;     roundsSinceHMGSpawn = 0
        removeLaserHUD();   laserActive = false;   laserTimeRemaining = 0

        shotgunPickupNode?.removeFromParent(); shotgunPickupNode = nil
        hmgPickupNode?.removeFromParent(); hmgPickupNode = nil
        laserPickupNode?.removeFromParent(); laserPickupNode = nil

        players.removeAll()
        setupPlayer()
        updateHUD()

        levelNumber = 1

        if let levels = LevelLoader.loadLevels() {
            roundManager?.spawnTimer?.invalidate()
            roundManager = RoundManager(levelData: levels)
            roundManager?.lowEffectsEnabled = lowEffectsEnabled
            roundManager?.spawnFPS30CapHint = fps30CapEnabled
            roundManager?.shadowsDisabled = shadowsDisabled
            roundManager?.startRound(in: self)
        }

        // Round 1 chance-based spawns and laser test spawn
        attemptSpawnShotgunForRound()
        attemptSpawnHMGForRound()
        spawnLaserPickupAtRound1()

        isPaused = false
        isGameOver = false
        gameOverAlertPresented = false
    }

    // MARK: - Hamburger UI
    private func addHamburger() {
        let container = SKNode()
        container.name = "hamburger"
        container.zPosition = 200

        let plate = SKShapeNode(rectOf: CGSize(width: 56, height: 48), cornerRadius: 8)
        plate.fillColor = .clear
        plate.strokeColor = .clear
        container.addChild(plate)

        let barsSize = CGSize(width: 32, height: 24)
        let barH: CGFloat = 3
        for y: CGFloat in [8, 0, -8] {
            let bar = SKShapeNode(rectOf: CGSize(width: barsSize.width, height: barH), cornerRadius: 1.2)
            bar.fillColor = .white
            bar.strokeColor = .clear
            bar.position = CGPoint(x: 0, y: y)
            container.addChild(bar)
        }

        hamburgerNode = container
        addChild(hamburgerNode!)
        positionHamburger()
    }

    private func positionHamburger() {
        guard let node = hamburgerNode else { return }
        let r = safeFrame()
        let padding: CGFloat = 12
        let bbox = node.calculateAccumulatedFrame()
        node.position = CGPoint(
            x: r.minX + padding + bbox.width * 0.5,
            y: r.maxY - padding - bbox.height * 0.5
        )
    }

    // MARK: - Touches
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let p = t.location(in: self)
        let node = atPoint(p)
        if node.name == "hamburger" || node.parent?.name == "hamburger" {
            openSettings()
            return
        }
    }

    // MARK: - Settings menu
    func openSettings() {
        isPaused = true

        let overlay = SettingsOverlay(
            initialVolume: masterVolume,
            lowEffects: lowEffectsEnabled,
            fps30: fps30CapEnabled,
            disableShadows: shadowsDisabled,
            onVolumeChanged: { [weak self] v in self?.masterVolume = v },
            onToggleLowEffects: { [weak self] on in
                self?.lowEffectsEnabled = on
                self?.roundManager?.lowEffectsEnabled = on
            },
            onToggleFPS30: { [weak self] on in
                self?.fps30CapEnabled = on
                self?.roundManager?.spawnFPS30CapHint = on
            },
            onToggleShadows: { [weak self] off in
                self?.shadowsDisabled = off
                self?.roundManager?.shadowsDisabled = off
            },
            onResume: { [weak self] in
                self?.dismissSettings(resume: true)
            },
            onMainMenu: { [weak self] in
                self?.confirmExitToMainMenu()
            }
        )

        let host = UIHostingController(rootView: overlay)
        host.view.backgroundColor = .clear
        host.modalPresentationStyle = .overCurrentContext
        settingsHost = host

        if let vc = topViewController() {
            vc.present(host, animated: true, completion: nil)
        } else {
            self.view?.window?.rootViewController?.present(host, animated: true, completion: nil)
        }
    }

    private func dismissSettings(resume: Bool) {
        guard let host = settingsHost else { return }
        host.dismiss(animated: true) { [weak self] in
            self?.settingsHost = nil
            if resume { self?.isPaused = false }
        }
    }

    private func confirmExitToMainMenu() {
        guard let presenter = settingsHost else { return }
        let alert = UIAlertController(
            title: "Return to Main Menu?",
            message: "You’ll lose current level progress.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Exit", style: .destructive, handler: { _ in
            NotificationCenter.default.post(name: .AOTDExitToMainMenu, object: nil)
            self.dismissSettings(resume: false)
        }))
        presenter.present(alert, animated: true, completion: nil)
    }

    private func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let baseVC = base ?? self.view?.window?.rootViewController
        if let nav = baseVC as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = baseVC as? UITabBarController {
            return topViewController(base: tab.selectedViewController)
        }
        if let presented = baseVC?.presentedViewController {
            return topViewController(base: presented)
        }
        return baseVC
    }

    // MARK: - Graphics application
    private func applyGraphicsToManagersAndView() {
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

    // MARK: - Power-up helpers (Shotgun/HMG)

    private func attemptSpawnShotgunForRound() {
        guard shotgunPickupNode == nil else { return }

        let roll = Int.random(in: 1...100)
        var shouldSpawn = (roll <= 10) // 10%

        roundsSinceShotgunSpawn += 1
        if roundsSinceShotgunSpawn >= 3 { shouldSpawn = true }

        if shouldSpawn {
            spawnShotgunPickup()
            roundsSinceShotgunSpawn = 0
        }
    }

    private func attemptSpawnHMGForRound() {
        guard hmgPickupNode == nil else { return }

        let roll = Int.random(in: 1...100)
        var shouldSpawn = (roll <= 10) // 10%

        roundsSinceHMGSpawn += 1
        if roundsSinceHMGSpawn >= 5 { shouldSpawn = true } // guarantee every 5 rounds

        if shouldSpawn {
            spawnHMGPickup()
            roundsSinceHMGSpawn = 0
        }
    }

    private func spawnShotgunPickup() {
        guard shotgunPickupNode == nil, let player = players.first else { return }
        let node = SKSpriteNode(imageNamed: "shotgun")
        node.name = "powerup_shotgun"
        node.zPosition = 50
        node.size = CGSize(width: 56, height: 20)

        let r = safeFrame()
        let x = min(max(r.minX + 80, player.sprite.position.x + 100), r.maxX - 60)
        let y = min(max(r.minY + 80, player.sprite.position.y), r.maxY - 60)
        node.position = CGPoint(x: x, y: y)
        shotgunPickupNode = node

        let up = SKAction.scale(to: 1.06, duration: 0.6)
        let down = SKAction.scale(to: 0.94, duration: 0.6)
        node.run(.repeatForever(.sequence([up, down])))

        addChild(node)
    }

    private func spawnHMGPickup() {
        guard hmgPickupNode == nil, let player = players.first else { return }
        let node = SKSpriteNode(imageNamed: "heavyMachineGun")
        node.name = "powerup_hmg"
        node.zPosition = 50
        node.size = CGSize(width: 64, height: 24)

        let r = safeFrame()
        let x = min(max(r.minX + 80, player.sprite.position.x + 100), r.maxX - 60)
        let y = min(max(r.minY + 80, player.sprite.position.y - 40), r.maxY - 60)
        node.position = CGPoint(x: x, y: y)
        hmgPickupNode = node

        let up = SKAction.scale(to: 1.06, duration: 0.6)
        let down = SKAction.scale(to: 0.94, duration: 0.6)
        node.run(.repeatForever(.sequence([up, down])))

        addChild(node)
    }

    // MARK: - Laser (test spawn at Round 1)
    private func spawnLaserPickupAtRound1() {
        guard levelNumber == 1, laserPickupNode == nil, let player = players.first else { return }
        let node = SKSpriteNode(imageNamed: "lasergun")
        node.name = "powerup_laser"
        node.zPosition = 50
        node.size = CGSize(width: 60, height: 18)

        let r = safeFrame()
        let x = min(max(r.minX + 80, player.sprite.position.x + 120), r.maxX - 60)
        let y = min(max(r.minY + 80, player.sprite.position.y + 40), r.maxY - 60)
        node.position = CGPoint(x: x, y: y)
        laserPickupNode = node

        let up = SKAction.scale(to: 1.06, duration: 0.6)
        let down = SKAction.scale(to: 0.94, duration: 0.6)
        node.run(.repeatForever(.sequence([up, down])))

        addChild(node)
    }

    private func positionPowerup(_ node: SKSpriteNode?) {
        guard let node = node else { return }
        let r = safeFrame()
        let clampedX = min(max(r.minX + 40, node.position.x), r.maxX - 40)
        let clampedY = min(max(r.minY + 40, node.position.y), r.maxY - 40)
        node.position = CGPoint(x: clampedX, y: clampedY)
    }

    // MARK: - Pickup handlers

    private func handleShotgunPickup() {
        guard let player = players.first else { return }
        shotgunPickupNode?.removeFromParent()
        shotgunPickupNode = nil

        let shotgun = Weapon(type: .shotgun)
        player.setWeapon(shotgun) // unified muzzle anchor

        shotgunActive = true
        shotgunTimeRemaining = 10.0 // firing-only
        showShotgunHUD()
        updateShotgunHUD()
    }

    private func handleHMGPickup() {
        guard let player = players.first else { return }
        hmgPickupNode?.removeFromParent()
        hmgPickupNode = nil

        let hmg = Weapon(type: .heavyMachineGun)
        player.setWeapon(hmg) // unified muzzle anchor

        hmgActive = true
        hmgTimeRemaining = 12.0 // firing-only
        showHMGHUD()
        updateHMGHUD()
    }

    private func handleLaserPickup() {
        guard let player = players.first else { return }
        laserPickupNode?.removeFromParent()
        laserPickupNode = nil

        let laser = Weapon(type: .laserGun)
        player.setWeapon(laser) // unified muzzle anchor

        laserActive = true
        laserTimeRemaining = 7.0 // firing-only
        showLaserHUD()
        updateLaserHUD()
    }

    // MARK: - Firing-time timers
    @objc private func onPlayerFiredShot(_ note: Notification) {
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

    private func endShotgunPowerup() {
        guard shotgunActive, let player = players.first else { return }
        shotgunActive = false
        shotgunTimeRemaining = 0
        let defaultMG = Weapon(type: .machineGun)
        player.setWeapon(defaultMG)
        removeShotgunHUD()
    }

    private func endHMGPowerup() {
        guard hmgActive, let player = players.first else { return }
        hmgActive = false
        hmgTimeRemaining = 0
        let defaultMG = Weapon(type: .machineGun)
        player.setWeapon(defaultMG)
        removeHMGHUD()
    }

    private func endLaserPowerup() {
        guard laserActive, let player = players.first else { return }
        laserActive = false
        laserTimeRemaining = 0
        let defaultMG = Weapon(type: .machineGun)
        player.setWeapon(defaultMG)
        removeLaserHUD()
    }

    // MARK: - HUD helpers
    private func showShotgunHUD() { shotgunTimerLabel?.isHidden = false }
    private func removeShotgunHUD() { shotgunTimerLabel?.isHidden = true; shotgunTimerLabel?.text = "" }
    private func updateShotgunHUD() {
        guard let lbl = shotgunTimerLabel else { return }
        guard shotgunActive else { lbl.isHidden = true; return }
        lbl.isHidden = false
        let t = max(0, shotgunTimeRemaining)
        lbl.text = String(format: "Shotgun: %.1fs", t)
    }

    private func showHMGHUD() { hmgTimerLabel?.isHidden = false }
    private func removeHMGHUD() { hmgTimerLabel?.isHidden = true; hmgTimerLabel?.text = "" }
    private func updateHMGHUD() {
        guard let lbl = hmgTimerLabel else { return }
        guard hmgActive else { lbl.isHidden = true; return }
        lbl.isHidden = false
        let t = max(0, hmgTimeRemaining)
        lbl.text = String(format: "HMG: %.1fs", t)
    }

    private func showLaserHUD() { laserTimerLabel?.isHidden = false }
    private func removeLaserHUD() { laserTimerLabel?.isHidden = true; laserTimerLabel?.text = "" }
    private func updateLaserHUD() {
        guard let lbl = laserTimerLabel else { return }
        guard laserActive else { lbl.isHidden = true; return }
        lbl.isHidden = false
        let t = max(0, laserTimeRemaining)
        lbl.text = String(format: "Laser: %.1fs", t)
    }
}

// MARK: - SwiftUI Overlay
private struct SettingsOverlay: View {
    @State var volume: Float
    @State var lowEffects: Bool
    @State var fps30: Bool
    @State var disableShadows: Bool

    let onVolumeChanged: (Float) -> Void
    let onToggleLowEffects: (Bool) -> Void
    let onToggleFPS30: (Bool) -> Void
    let onToggleShadows: (Bool) -> Void
    let onResume: () -> Void
    let onMainMenu: () -> Void

    init(
        initialVolume: Float,
        lowEffects: Bool,
        fps30: Bool,
        disableShadows: Bool,
        onVolumeChanged: @escaping (Float) -> Void,
        onToggleLowEffects: @escaping (Bool) -> Void,
        onToggleFPS30: @escaping (Bool) -> Void,
        onToggleShadows: @escaping (Bool) -> Void,
        onResume: @escaping () -> Void,
        onMainMenu: @escaping () -> Void
    ) {
        _volume = State(initialValue: initialVolume)
        _lowEffects = State(initialValue: lowEffects)
        _fps30 = State(initialValue: fps30)
        _disableShadows = State(initialValue: disableShadows)
        self.onVolumeChanged = onVolumeChanged
        self.onToggleLowEffects = onToggleLowEffects
        self.onToggleFPS30 = onToggleFPS30
        self.onToggleShadows = onToggleShadows
        self.onResume = onResume
        self.onMainMenu = onMainMenu
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()

            VStack(spacing: 18) {
                Text("Settings").font(.title.bold())

                VStack(alignment: .leading, spacing: 10) {
                    Text("Volume \(Int(volume * 100))%")
                    Slider(value: Binding(get: {
                        Double(volume)
                    }, set: { newVal in
                        volume = Float(newVal)
                        onVolumeChanged(Float(newVal))
                    }), in: 0...1)
                }

                Divider().padding(.vertical, 6)

                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Low Effects (performance)", isOn: Binding(get: { lowEffects }, set: {
                        lowEffects = $0; onToggleLowEffects($0)
                    }))
                    Toggle("Cap at 30 FPS", isOn: Binding(get: { fps30 }, set: {
                        fps30 = $0; onToggleFPS30($0)
                    }))
                    Toggle("Disable Shadows", isOn: Binding(get: { disableShadows }, set: {
                        disableShadows = $0; onToggleShadows($0)
                    }))
                }

                HStack(spacing: 12) {
                    Button("Resume") { onResume() }
                        .buttonStyle(.borderedProminent)
                    Button("Main Menu") { onMainMenu() }
                        .buttonStyle(.bordered)
                }
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
            .padding(.horizontal, 24)
        }
    }
}
