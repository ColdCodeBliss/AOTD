import SwiftUI

struct LaunchMenuView: View {
    @State private var showGameView = false
    @State private var showMultiplayerAlert = false
    @State private var showSettingsView = false
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all) // Background color
            
            VStack(spacing: 20) {
                Button("Game Mode") {
                    // Show selection between Single Player / Multiplayer
                    showGameModeSelection()
                }
                .frame(width: 200, height: 50)
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
                
                Button("Settings") {
                    showSettingsView = true
                }
                .frame(width: 200, height: 50)
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
                
                Button("Exit") {
                    exit(0)
                }
                .frame(width: 200, height: 50)
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .navigationDestination(isPresented: $showGameView) {
            GameView()
        }
        .sheet(isPresented: $showSettingsView) {
            SettingsView() // SwiftUI version of SettingsViewController
        }
    }
    
    private func showGameModeSelection() {
        let alert = UIAlertController(title: "Select Game Mode", message: "Single Player or Multiplayer?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Single Player", style: .default) { _ in
            showGameView = true
        })
        alert.addAction(UIAlertAction(title: "Multiplayer", style: .default) { _ in
            showMultiplayerAlert = true
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // UIKit bridge for alert
        if let root = UIApplication.shared.windows.first?.rootViewController {
            root.present(alert, animated: true, completion: nil)
        }
    }
}
