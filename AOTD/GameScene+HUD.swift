import SpriteKit

extension GameScene {
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

        let sLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        sLabel.fontSize = 18
        sLabel.fontColor = .yellow
        sLabel.zPosition = 101
        sLabel.text = ""
        sLabel.isHidden = true
        shotgunTimerLabel = sLabel
        addChild(sLabel)

        let hLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        hLabel.fontSize = 18
        hLabel.fontColor = .orange
        hLabel.zPosition = 101
        hLabel.text = ""
        hLabel.isHidden = true
        hmgTimerLabel = hLabel
        addChild(hLabel)

        let lLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        lLabel.fontSize = 18
        lLabel.fontColor = SKColor(cgColor: CGColor(red: 0.4, green: 0.95, blue: 1.0, alpha: 1.0))
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

    func positionHUD() {
        guard let heart = livesHeart, let label = livesLabel else { return }
        let r = self.safeFrame()
        let padding: CGFloat = 12

        let heartHalfW = heart.size.width * 0.5
        let heartHalfH = heart.size.height * 0.5
        heart.position = CGPoint(x: r.maxX - padding - heartHalfW, y: r.maxY - padding - heartHalfH)
        label.position = CGPoint(x: heart.position.x + 25, y: heart.position.y - 1)
    }

    func updateHUD() {
        let lives = max(0, players.first?.lives ?? 0)
        livesLabel?.text = "\(lives)"
    }

    func positionShotgunHUD() {
        guard let lbl = shotgunTimerLabel else { return }
        let r = self.safeFrame()
        lbl.position = CGPoint(x: r.midX, y: r.maxY - 24)
    }

    func positionHMGHUD() {
        guard let lbl = hmgTimerLabel else { return }
        let r = self.safeFrame()
        lbl.position = CGPoint(x: r.midX, y: r.maxY - 44)
    }

    func positionLaserHUD() {
        guard let lbl = laserTimerLabel else { return }
        let r = self.safeFrame()
        lbl.position = CGPoint(x: r.midX, y: r.maxY - 64)
    }

    func showShotgunHUD() { shotgunTimerLabel?.isHidden = false }
    func removeShotgunHUD() { shotgunTimerLabel?.isHidden = true; shotgunTimerLabel?.text = "" }
    func updateShotgunHUD() {
        guard let lbl = shotgunTimerLabel else { return }
        guard shotgunActive else { lbl.isHidden = true; return }
        lbl.isHidden = false
        let t = max(0, shotgunTimeRemaining)
        lbl.text = String(format: "Shotgun: %.1fs", t)
    }

    func showHMGHUD() { hmgTimerLabel?.isHidden = false }
    func removeHMGHUD() { hmgTimerLabel?.isHidden = true; hmgTimerLabel?.text = "" }
    func updateHMGHUD() {
        guard let lbl = hmgTimerLabel else { return }
        guard hmgActive else { lbl.isHidden = true; return }
        lbl.isHidden = false
        let t = max(0, hmgTimeRemaining)
        lbl.text = String(format: "HMG: %.1fs", t)
    }

    func showLaserHUD() { laserTimerLabel?.isHidden = false }
    func removeLaserHUD() { laserTimerLabel?.isHidden = true; laserTimerLabel?.text = "" }
    func updateLaserHUD() {
        guard let lbl = laserTimerLabel else { return }
        guard laserActive else { lbl.isHidden = true; return }
        lbl.isHidden = false
        let t = max(0, laserTimeRemaining)
        lbl.text = String(format: "Laser: %.1fs", t)
    }
}
