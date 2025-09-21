//
//  SettingsOverlay.swift
//  AOTD
//
//  Created by Ryan Bliss on 9/19/25.
//

import SwiftUI

struct SettingsOverlay: View {
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
                    Slider(value: Binding(
                        get: { Double(volume) },
                        set: { newVal in
                            volume = Float(newVal)
                            onVolumeChanged(Float(newVal))
                        }
                    ), in: 0...1)
                }

                Divider().padding(.vertical, 6)

                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Low Effects (performance)", isOn: Binding(
                        get: { lowEffects },
                        set: { lowEffects = $0; onToggleLowEffects($0) }
                    ))
                    Toggle("Cap at 30 FPS", isOn: Binding(
                        get: { fps30 },
                        set: { fps30 = $0; onToggleFPS30($0) }
                    ))
                    Toggle("Disable Shadows", isOn: Binding(
                        get: { disableShadows },
                        set: { disableShadows = $0; onToggleShadows($0) }
                    ))
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
