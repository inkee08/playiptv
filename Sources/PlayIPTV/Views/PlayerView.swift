import SwiftUI
import AVKit

struct PlayerView: View {
    let url: URL
    @Bindable var appState: AppState
    @Binding var isFullscreen: Bool
    var shouldPlay: Bool = true 
    
    // Use the Shared Player Manager
    @ObservedObject private var playerManager = PlayerManager.shared
    
    var body: some View {
        VideoPlayer(player: playerManager.player)
            .ignoresSafeArea()
            .focusable()
            .onAppear {
                print("DEBUG: PlayerView onAppear. URL: \(url) | shouldPlay: \(shouldPlay)")
                if shouldPlay { 
                    playerManager.play(url: url)
                }
            }
            .onChange(of: url) { _, newUrl in
                print("DEBUG: PlayerView URL changed to: \(newUrl)")
                if shouldPlay { 
                    playerManager.play(url: newUrl)
                }
            }
            .onChange(of: shouldPlay) { _, play in
                print("DEBUG: PlayerView shouldPlay changed to: \(play)")
                if play {
                    playerManager.play(url: url)
                } else {
                    // Only stop if we are the one controlling it? 
                    // Actually, if shouldPlay becomes false (e.g. detached mode starts),
                    // we DON'T necessarily want to stop the manager if the Detached View is about to pick it up.
                    // BUT, current architecture implies "Handover".
                    // However, if we share the player instance, "Handover" is instant.
                    // If Attached View says "Stop" and Detached View says "Play" to the SAME player, we might have a race/conflict.
                    
                    // BETTER APPROACH:
                    // If we share the player object, we don't need to stop/start.
                    // We just need the view to display the player.
                    // But if we want to support "Switching", we just let the new view appear.
                    
                    // HOWEVER, to be safe/clean for the prompt "Double Audio":
                    // If this view is told NOT to play, we should ensure the player isn't playing *on its behalf*.
                    // But since it's a singleton, "Stop" stops it for everyone.
                    // So we only "Stop" if we strictly mean "Stop Everything".
                    
                    // Refined Logic for Singleton:
                    // We don't need to "Stop" when switching views, because the new view will just show the same player.
                    // We only need to "Stop" when the user actually closes the stream.
                }
            }
            .onDisappear {
                // With Singleton PlayerManager, we share the same player instance
                // across all views (attached, detached). We should NOT stop playback
                // when a view disappears because we might be switching modes.
                // The player will be stopped explicitly when the user closes a channel.
                print("DEBUG: PlayerView onDisappear - keeping player alive for mode switching")
            }
            .onChange(of: appState.playPauseSignal) { _, _ in
               playerManager.togglePlayPause()
            }
    }
}
