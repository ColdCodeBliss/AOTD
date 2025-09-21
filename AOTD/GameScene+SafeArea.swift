//
//  GameScene+SafeArea.swift
//  AOTD
//
//  Created by Ryan Bliss on 9/19/25.
//

import UIKit
import SpriteKit

extension GameScene {
    /// Current view's safe-area insets (0 if unavailable).
    func safeAreaInsets() -> UIEdgeInsets {
        view?.window?.safeAreaInsets ?? .zero
    }

    /// A rect you can use for HUD/layout, inset by the current safe area.
    func safeFrame() -> CGRect {
        let sz = view?.bounds.size ?? size
        return CGRect(origin: .zero, size: sz).inset(by: safeAreaInsets())
    }
}
