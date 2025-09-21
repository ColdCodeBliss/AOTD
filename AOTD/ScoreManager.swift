//
//  ScoreManager.swift
//  AOTD
//
//  Created by Ryan Bliss on 9/20/25.
//

import Foundation

protocol ScoreHUDDelegate: AnyObject {
    func scoreDidChange(to newScore: Int, multiplier: Int)
}

/// Encapsulates all scoring & multiplier logic. UI-agnostic; updates go to delegate.
final class ScoreManager {

    struct Config {
        var maxMultiplier: Int = 4
        var killsPerMultiplierStep: Int = 5
        var baseKillPoints: Int = 300
        var baseRoundStartPoints: Int = 100
        var baseRoundCompletePoints: Int = 200
        /// Linear growth per level after L1: final = base * (1 + growthRatePerLevel*(level-1))
        var growthRatePerLevel: Double = 0.05
    }

    private(set) var score: Int = 0
    private(set) var multiplier: Int = 1
    private var killStreak: Int = 0

    let config: Config
    weak var delegate: ScoreHUDDelegate?

    init(config: Config = Config()) {
        self.config = config
    }

    // MARK: - Public API

    func awardKill() {
        addScore(config.baseKillPoints)
        killStreak += 1
        if killStreak % config.killsPerMultiplierStep == 0 {
            multiplier = min(config.maxMultiplier, multiplier + 1)
            notify()
        }
    }

    func awardRoundStart(level: Int) {
        let pts = scaled(base: config.baseRoundStartPoints, level: level)
        addScore(pts)
    }

    func awardRoundComplete(level: Int) {
        let pts = scaled(base: config.baseRoundCompletePoints, level: level)
        addScore(pts)
    }

    func resetOnLifeLoss() {
        multiplier = 1
        killStreak = 0
        notify()
    }

    func resetAll() {
        score = 0
        multiplier = 1
        killStreak = 0
        notify()
    }

    // MARK: - Internals

    private func addScore(_ raw: Int) {
        let m = max(1, min(multiplier, config.maxMultiplier))
        score += raw * m
        notify()
    }

    private func scaled(base: Int, level: Int) -> Int {
        let l = max(1, level)
        let factor = 1.0 + config.growthRatePerLevel * Double(l - 1)
        return Int((Double(base) * factor).rounded(.toNearestOrAwayFromZero))
    }

    private func notify() {
        delegate?.scoreDidChange(to: score, multiplier: multiplier)
    }
}
