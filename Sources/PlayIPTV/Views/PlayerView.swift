import SwiftUI
import AVKit

struct PlayerView: View {
    let url: URL
    @State private var player = AVPlayer()
    
    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                playUrl()
            }
            .onChange(of: url) { 
                playUrl()
            }
            .onDisappear {
                player.pause()
            }
    }
    
    private func playUrl() {
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        player.play()
    }
}
