import SpriteKit

private enum HUDBarID: String {
    case shotgun = "shotgun"
    case hmg     = "hmg"
    case laser   = "laser"
}

extension GameScene {

    // MARK: - Setup

    func setupHUD() {
        // Lives (unchanged)
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

        // Keep the old labels but hide them
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

        // NEW: Progress bars
        ensureBarNodes()

        positionHUD()
        positionShotgunHUD()
        positionHMGHUD()
        positionLaserHUD()
    }

    // MARK: - Lives

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

    // MARK: - Bar creation & layout

    private func ensureBarNodes() {
        // Thinner + shorter bars: width 180, height 6

        // Shotgun bar (yellow)
        ensureBar(id: .shotgun,
                  width: 180, height: 6,
                  bgColor: SKColor(white: 1, alpha: 0.12),
                  fillColor: .yellow,
                  z: 101)

        // HMG bar (orange)
        ensureBar(id: .hmg,
                  width: 180, height: 6,
                  bgColor: SKColor(white: 1, alpha: 0.12),
                  fillColor: .orange,
                  z: 101)

        // Laser bar (cyan)
        ensureBar(id: .laser,
                  width: 180, height: 6,
                  bgColor: SKColor(white: 1, alpha: 0.12),
                  fillColor: SKColor(cgColor: CGColor(red: 0.4, green: 0.95, blue: 1.0, alpha: 1.0)),
                  z: 101)
    }

    private func ensureBar(id: HUDBarID,
                           width: CGFloat,
                           height: CGFloat,
                           bgColor: SKColor,
                           fillColor: SKColor,
                           z: CGFloat) {
        let bgName   = "hud_\(id.rawValue)_bg"
        let fillName = "hud_\(id.rawValue)_fill"

        if childNode(withName: bgName) == nil {
            let bg = SKSpriteNode(color: bgColor, size: CGSize(width: width, height: height))
            bg.name = bgName
            bg.zPosition = z
            bg.alpha = 0.9
            // Store width for layout math later
            bg.userData = NSMutableDictionary()
            bg.userData?["width"] = width
            addChild(bg)

            let fill = SKSpriteNode(color: fillColor, size: CGSize(width: width, height: height))
            fill.name = fillName
            fill.zPosition = z + 1
            fill.alpha = 0.95
            // Left-anchor so changing width “drains” to the right
            fill.anchorPoint = CGPoint(x: 0, y: 0.5)
            addChild(fill)

            // Start hidden
            bg.isHidden = true
            fill.isHidden = true
        }
    }

    private func layoutBar(id: HUDBarID, centerY: CGFloat) {
        let bgName   = "hud_\(id.rawValue)_bg"
        let fillName = "hud_\(id.rawValue)_fill"
        guard
            let bg   = childNode(withName: bgName)   as? SKSpriteNode,
            let fill = childNode(withName: fillName) as? SKSpriteNode
        else { return }

        let r = self.safeFrame()
        let fullWidth = (bg.userData?["width"] as? CGFloat) ?? bg.size.width

        // Center the background horizontally at r.midX
        bg.position = CGPoint(x: r.midX, y: centerY)

        // Place the fill so its LEFT edge aligns to bg’s left edge
        let leftX = r.midX - fullWidth * 0.5
        fill.position = CGPoint(x: leftX, y: centerY)
    }

    private func setBarProgress(id: HUDBarID, remaining: TimeInterval, maxTime: TimeInterval) {
        let fillName = "hud_\(id.rawValue)_fill"
        let bgName   = "hud_\(id.rawValue)_bg"
        guard
            let fill = childNode(withName: fillName) as? SKSpriteNode,
            let bg   = childNode(withName: bgName)   as? SKSpriteNode
        else { return }

        let fullWidth = (bg.userData?["width"] as? CGFloat) ?? bg.size.width
        let p = Swift.max(0, Swift.min(1, CGFloat(remaining / maxTime)))
        fill.size.width = fullWidth * p
    }

    private func showBar(id: HUDBarID, initialRemaining: TimeInterval) {
        let fillName = "hud_\(id.rawValue)_fill"
        let bgName   = "hud_\(id.rawValue)_bg"
        guard
            let fill = childNode(withName: fillName) as? SKSpriteNode,
            let bg   = childNode(withName: bgName)   as? SKSpriteNode
        else { return }

        // Remember max for scaling (so we don’t need new stored properties)
        bg.userData?["max"] = initialRemaining

        bg.isHidden   = false
        fill.isHidden = false

        // Start “full”
        setBarProgress(id: id, remaining: initialRemaining, maxTime: initialRemaining)
    }

    private func hideBar(id: HUDBarID) {
        childNode(withName: "hud_\(id.rawValue)_bg")?.isHidden   = true
        childNode(withName: "hud_\(id.rawValue)_fill")?.isHidden = true
    }

    private func currentBarMax(id: HUDBarID) -> TimeInterval {
        let bgName = "hud_\(id.rawValue)_bg"
        if let bg = childNode(withName: bgName) as? SKSpriteNode,
           let max = bg.userData?["max"] as? TimeInterval {
            return max
        }
        return 1 // fallback to avoid div-by-zero; will be overwritten on show*
    }

    // MARK: - Positions (keep your original vertical spacing)

    func positionShotgunHUD() {
        let r = self.safeFrame()
        layoutBar(id: .shotgun, centerY: r.maxY - 24)
    }

    func positionHMGHUD() {
        let r = self.safeFrame()
        layoutBar(id: .hmg, centerY: r.maxY - 44)
    }

    func positionLaserHUD() {
        let r = self.safeFrame()
        layoutBar(id: .laser, centerY: r.maxY - 64)
    }

    // MARK: - API (same names as before, but controlling bars now)

    func showShotgunHUD() {
        shotgunTimerLabel?.isHidden = true
        showBar(id: .shotgun, initialRemaining: shotgunTimeRemaining)
    }

    func removeShotgunHUD() {
        hideBar(id: .shotgun)
        shotgunTimerLabel?.isHidden = true
        shotgunTimerLabel?.text = ""
    }

    func updateShotgunHUD() {
        guard shotgunActive else { hideBar(id: .shotgun); return }
        let maxTime = currentBarMax(id: .shotgun)
        setBarProgress(id: .shotgun, remaining: shotgunTimeRemaining, maxTime: maxTime)
    }

    func showHMGHUD() {
        hmgTimerLabel?.isHidden = true
        showBar(id: .hmg, initialRemaining: hmgTimeRemaining)
    }

    func removeHMGHUD() {
        hideBar(id: .hmg)
        hmgTimerLabel?.isHidden = true
        hmgTimerLabel?.text = ""
    }

    func updateHMGHUD() {
        guard hmgActive else { hideBar(id: .hmg); return }
        let maxTime = currentBarMax(id: .hmg)
        setBarProgress(id: .hmg, remaining: hmgTimeRemaining, maxTime: maxTime)
    }

    func showLaserHUD() {
        laserTimerLabel?.isHidden = true
        showBar(id: .laser, initialRemaining: laserTimeRemaining)
    }

    func removeLaserHUD() {
        hideBar(id: .laser)
        laserTimerLabel?.isHidden = true
        laserTimerLabel?.text = ""
    }

    func updateLaserHUD() {
        guard laserActive else { hideBar(id: .laser); return }
        let maxTime = currentBarMax(id: .laser)
        setBarProgress(id: .laser, remaining: laserTimeRemaining, maxTime: maxTime)
    }
}
