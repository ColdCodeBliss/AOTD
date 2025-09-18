import SwiftUI

struct SettingsView: View {
    @State private var soundEnabled = true
    @State private var volume = 0.5
    
    var body: some View {
        VStack(spacing: 20) {
            Toggle("Sound Effects", isOn: $soundEnabled)
            Slider(value: $volume, in: 0...1)
            Button("Reset to Default") {
                soundEnabled = true
                volume = 0.5
            }
            .buttonStyle(MainButtonStyle())
        }
        .padding()
    }
}
