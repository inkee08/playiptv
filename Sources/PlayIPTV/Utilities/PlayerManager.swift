import Foundation
import VLCKit

@MainActor
class PlayerManager: NSObject, ObservableObject {
    static let shared = PlayerManager()
    
    @Published private(set) var player = VLCMediaPlayer()
    @Published var isPlaying: Bool = false
    @Published var isLoading: Bool = false
    
    private var currentUrl: URL?
    private var currentStreamId: String?
    private var positionSaveTimer: Timer?
    private var debounceTask: Task<Void, Never>?
    
    override init() {
        super.init()
        player.delegate = self
        print("DEBUG: VLC → PlayerManager initialized")
    }
    
    // MARK: - Playback Control
    
    func play(url: URL, streamId: String? = nil, startPosition: Double? = nil, force: Bool = false) {
        if !force && currentUrl == url && player.isPlaying {
            print("DEBUG: VLC → Already playing \(url.lastPathComponent)")
            return
        }
        
        print("DEBUG: VLC → Loading \(url.lastPathComponent)")
        currentUrl = url
        currentStreamId = streamId
        
        // Explicitly start loading
        isLoading = true
        
        let media = VLCMedia(url: url)
        player.media = media
        player.play()
        
        // Seek to saved position if provided
        if let position = startPosition {
            // Wait a bit for media to load before seeking
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.player.time = VLCTime(int: Int32(position * 1000))
            }
        }
        
        // Start periodic position saving for VOD
        startPositionTracking()
    }
    
    func stop() {
        print("DEBUG: VLC → Stopping playback")
        saveCurrentPosition()
        stopPositionTracking()
        
        debounceTask?.cancel()
        debounceTask = nil
        
        player.stop()
        player.media = nil
        currentUrl = nil
        currentStreamId = nil
        isPlaying = false
        isLoading = false
    }
    
    private func startPositionTracking() {
        stopPositionTracking()
        
        // Save position every 10 seconds
        positionSaveTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.saveCurrentPosition()
            }
        }
    }
    
    private func stopPositionTracking() {
        positionSaveTimer?.invalidate()
        positionSaveTimer = nil
    }
    
    private func saveCurrentPosition() {
        guard let streamId = currentStreamId,
              player.isSeekable else { return }
        
        let position = Double(player.time.intValue) / 1000.0 // Convert to seconds
        let duration = Double(player.media?.length.intValue ?? 0) / 1000.0
        PlaybackPositionManager.shared.savePosition(streamId: streamId, position: position, duration: duration)
    }
    
    func togglePlayPause() {
        if player.isPlaying {
            player.pause()
        } else {
            player.play()
        }
    }
    
    func setVolume(_ volume: Int32) {
        player.audio?.volume = volume
    }
    
    func skip(seconds: Int) {
        guard player.isSeekable else { return }
        let currentTime = Int(player.time.intValue)
        let newTime = VLCTime(int: Int32(currentTime + (seconds * 1000))) // milliseconds
        player.time = newTime
    }
    
    func restart() {
        guard player.isSeekable else { return }
        player.time = VLCTime(int: 0)
        player.play()
    }
    
    func seek(to seconds: Double) {
        guard player.isSeekable else { return }
        player.time = VLCTime(int: Int32(seconds * 1000)) // Convert to milliseconds
    }
    
    func selectAudioTrack(index: Int) {
        // VLC uses indexes from audioTrackIndexes array
        if let indexes = player.audioTrackIndexes as? [Int32],
           index >= 0 && index < indexes.count {
            let vlcIndex = indexes[index]
            player.currentAudioTrackIndex = vlcIndex
            print("DEBUG: Audio - Array index: \(index), VLC index: \(vlcIndex), Current: \(player.currentAudioTrackIndex)")
            print("DEBUG: Audio - All VLC indexes: \(indexes)")
        }
    }
    
    func selectSubtitleTrack(index: Int) {
        if index == -1 {
            // Disable subtitles
            player.currentVideoSubTitleIndex = -1
            print("DEBUG: Subtitle - Disabled (set to -1)")
        } else if let indexes = player.videoSubTitlesIndexes as? [Int32],
                  index >= 0 && index < indexes.count {
            let vlcIndex = indexes[index]
            player.currentVideoSubTitleIndex = vlcIndex
            print("DEBUG: Subtitle - Array index: \(index), VLC index: \(vlcIndex), Current: \(player.currentVideoSubTitleIndex)")
            print("DEBUG: Subtitle - All VLC indexes: \(indexes)")
        }
    }
}

// MARK: - VLCMediaPlayerDelegate
extension PlayerManager: VLCMediaPlayerDelegate {
    nonisolated func mediaPlayerStateChanged(_ notification: Notification) {
        Task { @MainActor in
            isPlaying = player.isPlaying
            
            // Check loading state
            print("DEBUG: VLC State Changed: \(player.state.rawValue)")
            switch player.state {
            case .opening, .buffering:
                // Cancel pending stop
                debounceTask?.cancel()
                debounceTask = nil
                
                if !isLoading {
                    isLoading = true
                    print("DEBUG: Loading started")
                }
                
            default:
                // Debounce stop (wait 0.5s) to prevent flickering on retry loops
                debounceTask?.cancel() 
                debounceTask = Task {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    if !Task.isCancelled {
                        isLoading = false
                        print("DEBUG: Loading ended (State: \(player.state.rawValue))")
                    }
                }
            }
        }
    }
    
    nonisolated func mediaPlayerTimeChanged(_ notification: Notification) {
        Task { @MainActor in
            // If time is advancing, we are definitely playing -> hide loading
            if isLoading {
                print("DEBUG: Time changed, forcing loading end")
                isLoading = false
            }
        }
    }
}
