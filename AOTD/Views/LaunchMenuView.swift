import SwiftUI

struct LaunchMenuView: View {
    @State private var showGameView = false
    @State private var showSettingsView = false
    @State private var showMultiplayerAlert = false

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Button("Game Mode") {
                    showGameModeSelection()
                }
                .buttonStyle(MainButtonStyle())
                
                Button("Settings") {
                    showSettingsView = true
                }
                .buttonStyle(MainButtonStyle())
                
                Button("Exit") {
                    exit(0)
                }
                .buttonStyle(MainButtonStyle())
            }
        }
        .navigationDestination(isPresented: $showGameView) {
            GameView()
        }
        .sheet(isPresented: $showSettingsView) {
            SettingsView()
        }
        .alert("Multiplayer Mode", isPresented: $showMultiplayerAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Multiplayer feature coming soon!")
        }
    }
    
    // MARK: - Helper Functions
    private func showGameModeSelection() {
        let alert = UIAlertController(title: "Select Game Mode", message: "Single Player or Multiplayer?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Single Player", style: .default) { _ in
            showGameView = true
        })
        alert.addAction(UIAlertAction(title: "Multiplayer", style: .default) { _ in
            showMultiplayerAlert = true
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // Present alert using UIWindowScene
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first,
           let root = window.rootViewController {
            root.present(alert, animated: true)
        }
    }
}

// MARK: - Button Style
struct MainButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 200, height: 50)
            .background(Color.gray)
            .foregroundColor(.white)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}
