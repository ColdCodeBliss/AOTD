//
//  SettingsView.swift
//  AOTD
//
//  Created by Ryan Bliss on 9/18/25.
//


import SwiftUI

struct SettingsView: View {
    @State private var soundEnabled: Bool = true
    @State private var volume: Double = 0.5
    
    var body: some View {
        VStack(spacing: 20) {
            Toggle("Sound Effects", isOn: $soundEnabled)
            Slider(value: $volume, in: 0...1)
            Button("Reset to Default") {
                soundEnabled = true
                volume = 0.5
            }
        }
        .padding()
    }
}
