import SwiftUI
import VLCKit

/// Singleton container for VLC video view - ensures view is never recreated
@MainActor
class VLCViewContainer {
    static let shared = VLCViewContainer()
    
    let videoView: VLCVideoView
    
    private init() {
        videoView = VLCVideoView()
        videoView.autoresizingMask = [.width, .height]
        PlayerManager.shared.player.drawable = videoView
        print("DEBUG: VLC → Singleton video view created and drawable set")
    }
}

struct PlayerView: View {
    @Environment(AppState.self) private var appState
    @ObservedObject private var playerManager = PlayerManager.shared
    @State private var showControls = false
    var isFullscreen: Bool = false
    
    var body: some View {
        ZStack {
            SingletonVLCView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor))
            
            // Loading Overlay
            if playerManager.isLoading {
                Color.black
                    .overlay {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .controlSize(.large)
                            .environment(\.colorScheme, .dark) // Forces white spinner
                    }
                    .transition(.opacity)
                    .zIndex(1)
            }
            
            // Media controls overlay
            if showControls, let channel = appState.selectedChannel {
                MediaControlsView(channel: channel, isFullscreen: isFullscreen)
                    .transition(.opacity)
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                showControls = hovering
            }
        }
        .onTapGesture {
            withAnimation {
                showControls.toggle()
            }
        }
        .onChange(of: appState.playPauseSignal) { _, _ in
            PlayerManager.shared.togglePlayPause()
        }
    }
}

struct SingletonVLCView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        print("DEBUG: VLC → Returning singleton video view")
        let containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
        
        let vlcView = VLCViewContainer.shared.videoView
        vlcView.frame = containerView.bounds
        vlcView.autoresizingMask = [.width, .height]
        containerView.addSubview(vlcView)
        
        // Also set background on the VLC view itself
        vlcView.wantsLayer = true
        vlcView.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
        
        return containerView
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Ensure VLC view fills the container
        if let vlcView = nsView.subviews.first as? VLCVideoView {
            vlcView.frame = nsView.bounds
        }
    }
}

struct MediaControlsView: View {
    let channel: Channel
    let isFullscreen: Bool
    @ObservedObject private var playerManager = PlayerManager.shared
    @ObservedObject private var favoritesManager = FavoritesManager.shared // Add observation
    @Environment(AppState.self) private var appState
    @State private var volume: Double = 100
    @State private var isScrubbing: Bool = false
    @State private var scrubbingPosition: Double = 0
    @State private var currentTimeDisplay: Double = 0
    
    private var isLiveTV: Bool {
        // Live TV is anything that's not a series (movies and live TV don't have skip/restart)
        // Actually, movies should have controls, so check if it's truly live TV
        !channel.isSeries && (channel.categoryId.contains("Live") || channel.groupTitle?.contains("Live") == true)
    }
    
    private var currentTime: Double {
        isScrubbing ? scrubbingPosition : currentTimeDisplay
    }
    
    private var duration: Double {
        Double(playerManager.player.media?.length.intValue ?? 0) / 1000.0
    }
    
    private var isSeekable: Bool {
        playerManager.player.isSeekable
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
    
    private func updateCurrentTime() {
        currentTimeDisplay = Double(playerManager.player.time.intValue) / 1000.0
    }
    
    private func getNextEpisode() -> Episode? {
        guard let currentEpisode = appState.currentEpisode else { return nil }
        
        let episodes = appState.episodesForSeries.sorted { ep1, ep2 in
            if ep1.seasonNum != ep2.seasonNum {
                return ep1.seasonNum < ep2.seasonNum
            }
            return ep1.episodeNum < ep2.episodeNum
        }
        
        guard let currentIndex = episodes.firstIndex(where: { $0.id == currentEpisode.id }),
              currentIndex + 1 < episodes.count else {
            return nil
        }
        
        return episodes[currentIndex + 1]
    }
    
    private func playNextEpisode(_ episode: Episode) {
        guard let seriesId = appState.currentSeriesId,
              let series = appState.channels.first(where: { $0.streamId == seriesId }) else {
            return
        }
        
        let episodeChannel = Channel(
            streamId: episode.id,
            name: episode.title ?? "Episode \(episode.episodeNum)",
            logoUrl: series.logoUrl,
            streamUrl: episode.streamUrl,
            categoryId: series.categoryId,
            groupTitle: series.groupTitle,
            isSeries: false
        )
        
        appState.selectedChannel = episodeChannel
        appState.playChannel(episodeChannel, startPosition: nil)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Favorites Button in top LEFT overlay
            HStack {
                if let source = appState.selectedSource, let sourceUrl = source.url?.absoluteString {
                    // Determine target for favoriting
                    // If playing an episode, favorite the Series, otherwise favorite the channel
                    let targetChannel: Channel? = {
                        if let seriesId = appState.currentSeriesId,
                           let series = appState.channels.first(where: { $0.streamId == seriesId && $0.isSeries }) {
                            return series
                        }
                        return channel
                    }()
                    
                    if let target = targetChannel, !(isLiveTV && isFullscreen) {
                        Button(action: {
                            favoritesManager.toggleFavorite(channel: target, sourceUrl: sourceUrl)
                        }) {
                            Image(systemName: favoritesManager.isFavorite(streamId: target.streamId, sourceUrl: sourceUrl) ? "heart.fill" : "heart")
                                .font(.title2)
                                .foregroundColor(.pink)
                                .padding(10)
                                .background(Material.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .padding()
                        .help(appState.currentSeriesId != nil ? "Favorite Series" : "Toggle Favorite")
                    }
                }
                
                Spacer()
            }
            
            Spacer()
            
            // Timeline (VOD only) - above controls
            if !isLiveTV && isSeekable && duration > 0 {
                VStack(spacing: 8) {
                    // Timeline slider
                    Slider(
                        value: Binding(
                            get: { isScrubbing ? scrubbingPosition : currentTime },
                            set: { newValue in
                                isScrubbing = true
                                scrubbingPosition = newValue
                            }
                        ),
                        in: 0...duration,
                        onEditingChanged: { editing in
                            if !editing {
                                // Seek when user releases
                                playerManager.seek(to: scrubbingPosition)
                                isScrubbing = false
                            }
                        }
                    )
                    .tint(.white)
                    
                    // Time labels
                    HStack {
                        Text(formatTime(currentTime))
                            .font(.caption)
                            .foregroundColor(.white)
                        Spacer()
                        Text(formatTime(duration))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            }
            
            HStack(spacing: 20) {
                // Media controls on the left
                HStack(spacing: 15) {
                    // VOD controls (movies/series only)
                    if !isLiveTV {
                        Button(action: {
                            playerManager.restart()
                        }) {
                            Image(systemName: "backward.end.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                        .help("Restart from beginning")
                        
                        Button(action: {
                            playerManager.skip(seconds: -10)
                        }) {
                            Image(systemName: "gobackward.10")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                        .help("Skip back 10 seconds")
                    }
                    
                    // Play/Pause (all types)
                    Button(action: {
                        playerManager.togglePlayPause()
                    }) {
                        Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    .help(playerManager.isPlaying ? "Pause" : "Play")
                    
                    // VOD controls (movies/series only)
                    if !isLiveTV {
                        Button(action: {
                            playerManager.skip(seconds: 10)
                        }) {
                            Image(systemName: "goforward.10")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                        .help("Skip forward 10 seconds")
                        
                        // Next episode button (series only)
                        if let nextEpisode = getNextEpisode() {
                            Button(action: {
                                playNextEpisode(nextEpisode)
                            }) {
                                Image(systemName: "forward.end.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                            .buttonStyle(.plain)
                            .help("Next Episode")
                        }
                    }
                }
                
                Spacer()
                
                // Audio/Subtitle track selection
                HStack(spacing: 12) {
                    // Audio tracks - show if available
                    Menu {
                        if let audioTracks = playerManager.player.audioTrackNames as? [String] {
                            ForEach(Array(audioTracks.enumerated()), id: \.offset) { index, track in
                                Button(action: {
                                    playerManager.selectAudioTrack(index: index)
                                }) {
                                    HStack {
                                        Text(track)
                                        Spacer()
                                        if playerManager.player.currentAudioTrackIndex == Int32(index) {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.4))
                                .frame(width: 44, height: 44)
                            Image(systemName: "waveform.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .help("Audio Tracks")
                    
                    // Subtitle tracks - show if available
                    Menu {
                        Button(action: {
                            playerManager.selectSubtitleTrack(index: -1)
                        }) {
                            HStack {
                                Text("Off")
                                Spacer()
                                if playerManager.player.currentVideoSubTitleIndex == -1 {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        if let subtitleTracks = playerManager.player.videoSubTitlesNames as? [String] {
                            ForEach(Array(subtitleTracks.enumerated()), id: \.offset) { index, track in
                                Button(action: {
                                    playerManager.selectSubtitleTrack(index: index)
                                }) {
                                    HStack {
                                        Text(track)
                                        Spacer()
                                        if playerManager.player.currentVideoSubTitleIndex == Int32(index) {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.4))
                                .frame(width: 44, height: 44)
                            Image(systemName: "captions.bubble.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .help("Subtitles")
                }
                
                // Volume control on the right
                HStack(spacing: 8) {
                    Image(systemName: volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .foregroundColor(.white)
                    
                    Slider(value: $volume, in: 0...100)
                        .frame(width: 100)
                        .onChange(of: volume) { _, newValue in
                            playerManager.setVolume(Int32(newValue))
                        }
                }
                
                // Fullscreen toggle button
                Button(action: {
                    appState.fullscreenToggleSignal.toggle()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.4))
                            .frame(width: 44, height: 44)
                        Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .help(isFullscreen ? "Exit Fullscreen" : "Enter Fullscreen")
            }
            .padding(20)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .onAppear {
            // Initialize current time immediately
            updateCurrentTime()
            
            // Update timeline every 0.5 seconds
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                if !isScrubbing {
                    updateCurrentTime()
                }
            }
        }
    }
}
