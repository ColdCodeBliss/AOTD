import SpriteKit
import SwiftUI
import UIKit

extension GameScene {
    // MARK: Hamburger
    func addHamburger() {
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
        addChild(container)
        positionHamburger()
    }

    func positionHamburger() {
        guard let node = hamburgerNode else { return }
        let r = self.safeFrame()
        let padding: CGFloat = 12
        let bbox = node.calculateAccumulatedFrame()
        node.position = CGPoint(
            x: r.minX + padding + bbox.width * 0.5,
            y: r.maxY - padding - bbox.height * 0.5
        )
    }

    // MARK: Touches
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let p = t.location(in: self)
        let node = atPoint(p)
        if node.name == "hamburger" || node.parent?.name == "hamburger" {
            openSettings()
            return
        }
    }

    // MARK: Settings
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

    func dismissSettings(resume: Bool) {
        guard let host = settingsHost else { return }
        host.dismiss(animated: true) { [weak self] in
            self?.settingsHost = nil
            if resume { self?.isPaused = false }
        }
    }

    func confirmExitToMainMenu() {
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

    func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let baseVC = base ?? self.view?.window?.rootViewController
        if let nav = baseVC as? UINavigationController { return topViewController(base: nav.visibleViewController) }
        if let tab = baseVC as? UITabBarController { return topViewController(base: tab.selectedViewController) }
        if let presented = baseVC?.presentedViewController { return topViewController(base: presented) }
        return baseVC
    }

    // MARK: Game Over helpers used across scene
    func triggerGameOver() {
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

    func restartSinglePlayer() {
        removeAllActions()

        enumerateChildNodes(withName: "bullet") { node, _ in node.removeFromParent() }
        for z in zombies { z.removeFromParent() }
        zombies.removeAll()

        // Reset power-ups & HUD (extension provides this)
        resetAllPowerupsAndHUD()

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

        attemptSpawnShotgunForRound()
        attemptSpawnHMGForRound()
        run(.sequence([.wait(forDuration: 0.05), .run { [weak self] in self?.spawnLaserPickupAtRound1() }]))

        isPaused = false
        isGameOver = false
        gameOverAlertPresented = false
    }
}
