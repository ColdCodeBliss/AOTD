import SpriteKit
import SwiftUI
import UIKit

extension Notification.Name {
    static let AOTDExitToMainMenu = Notification.Name("AOTDExitToMainMenu")
    static let AOTDVolumeChanged  = Notification.Name("AOTDVolumeChanged")
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

    // MARK: - Menu/Settings
    private var hamburgerNode: SKNode?
    private var settingsHost: UIViewController?

    // persisted settings (simple, safe defaults)
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

        // Load levels and start first round
        if let levels = LevelLoader.loadLevels() {
            let rm = RoundManager(levelData: levels)
            // apply initial graphics prefs
            rm.lowEffectsEnabled = lowEffectsEnabled
            rm.spawnFPS30CapHint = fps30CapEnabled
            rm.shadowsDisabled = shadowsDisabled
            roundManager = rm
            roundManager?.startRound(in: self)
        }

        applyGraphicsToManagersAndView()

        // Ensure initial layout respects safe areas (after views are attached)
        positionHUD()
        positionHamburger()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        // These are now nil-safe; they’ll early-return if nodes aren’t created yet.
        positionHUD()
        positionHamburger()
    }

    // MARK: - Player Setup
    func setupPlayer() {
        guard let viewSize = view?.bounds.size else { return }
        let playerSprite = SKSpriteNode(imageNamed: "player_1")
        playerSprite.size = CGSize(width: 60, height: 60)
        playerSprite.position = CGPoint(x: viewSize.width/2, y: viewSize.height/2)
        let weapon = Weapon(type: .machineGun)
        let player = Player(sprite: playerSprite, weapon: weapon)
        players.append(player)
        addChild(player.sprite)

        let bob = SKAction.sequence([SKAction.moveBy(x: 0, y: 5, duration: 0.5),
                                     SKAction.moveBy(x: 0, y: -5, duration: 0.5)])
        player.sprite.run(SKAction.repeatForever(bob))
    }

    // MARK: - HUD Setup
    func setupHUD() {
        // Heart icon
        livesHeart = SKSpriteNode(imageNamed: "heart")
        livesHeart.size = CGSize(width: 30, height: 30)
        livesHeart.zPosition = 100
        addChild(livesHeart)

        // Lives label
        livesLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        livesLabel.fontSize = 24
        livesLabel.fontColor = .white
        livesLabel.horizontalAlignmentMode = .left
        livesLabel.verticalAlignmentMode = .center
        livesLabel.zPosition = 100
        livesLabel.text = "\(players.first?.lives ?? 3)"
        addChild(livesLabel)

        positionHUD()
    }

    // Safe-area helpers
    private func safeAreaInsets() -> UIEdgeInsets {
        view?.window?.safeAreaInsets ?? .zero
    }
    private func safeFrame() -> CGRect {
        let sz = view?.bounds.size ?? size
        return CGRect(origin: .zero, size: sz).inset(by: safeAreaInsets())
    }

    func positionHUD() {
        // Nil-safe: if HUD hasn’t been created yet, do nothing (prevents crash on early didChangeSize).
        guard let heart = livesHeart, let label = livesLabel else { return }

        let r = safeFrame()
        let padding: CGFloat = 12

        let heartHalfW = heart.size.width * 0.5
        let heartHalfH = heart.size.height * 0.5
        heart.position = CGPoint(
            x: r.maxX - padding - heartHalfW,
            y: r.maxY - padding - heartHalfH
        )

        label.position = CGPoint(
            x: heart.position.x + 25,
            y: heart.position.y - 1
        )
    }

    func updateHUD() {
        livesLabel?.text = "\(players.first?.lives ?? 0)"
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
    }

    // MARK: - Update loop
    override func update(_ currentTime: TimeInterval) {
        guard let player = players.first else { return }

        // Remove dead zombies immediately and keep array in sync
        zombies = zombies.filter { zombie in
            if zombie.health <= 0 {
                zombie.removeFromParent()
                return false
            }
            zombie.update(playerPosition: player.sprite.position)
            if zombie.frame.intersects(player.sprite.frame) {
                player.takeDamage()
                updateHUD()
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

        updateHUD()

        // Check if round complete
        if zombies.isEmpty,
           roundManager?.zombiesSpawnedThisRound ?? 0 >= roundManager?.maxZombiesThisRound ?? 0 {
            roundManager?.levelCompleted()
        }
    }

    // MARK: - Hamburger UI
    private func addHamburger() {
        let container = SKNode()
        container.name = "hamburger"
        container.zPosition = 200

        // Larger invisible tap plate for easier touch
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
        addChild(container)
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
        // other touch handling if any...
    }

    // MARK: - Settings menu
    func openSettings() {
        // pause gameplay
        isPaused = true

        // Build overlay using SwiftUI
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
        // Cap FPS on the SKView
        if let skv = view {
            skv.preferredFramesPerSecond = fps30CapEnabled ? 30 : 60
        }

        // Toggle any lighting/shadows if you add SKLightNodes later
        if shadowsDisabled {
            enumerateChildNodes(withName: "//") { node, _ in
                node.children.compactMap { $0 as? SKLightNode }.forEach { $0.isEnabled = false }
            }
        }

        // Let RoundManager know (affects spawn pacing / active caps)
        roundManager?.lowEffectsEnabled = lowEffectsEnabled
        roundManager?.spawnFPS30CapHint = fps30CapEnabled
        roundManager?.shadowsDisabled = shadowsDisabled
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
