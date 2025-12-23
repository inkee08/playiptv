import AVKit
import SwiftUI

@MainActor
class PlayerManager: ObservableObject {
    static let shared = PlayerManager()
    
    // The single, authoritative player instance
    let player = AVPlayer()
    
    // Track current URL to avoid reloading if same
    private(set) var currentUrl: URL?
    
    // Track play state
    @Published var isPlaying: Bool = false
    
    private init() {
        // Setup audio session if needed (macos handles this generally well but good for iOS parity)
    }
    
    func play(url: URL) {
        // If same URL, just ensure playing
        if currentUrl == url {
            player.play()
            isPlaying = true
            return
        }
        
        print("DEBUG: PlayerManager loading new URL: \(url)")
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        player.play()
        currentUrl = url
        isPlaying = true
    }
    
    func stop() {
        print("DEBUG: PlayerManager STOP called.")
        player.pause()
        player.replaceCurrentItem(with: nil)
        currentUrl = nil
        isPlaying = false
    }
    
    func togglePlayPause() {
        if player.rate == 0 {
            player.play()
            isPlaying = true
        } else {
            player.pause()
            isPlaying = false
        }
    }
}
