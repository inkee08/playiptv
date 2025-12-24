import Foundation
import VLCKit

@MainActor
class PlayerManager: NSObject, ObservableObject {
    static let shared = PlayerManager()
    
    @Published private(set) var player = VLCMediaPlayer()
    @Published var isPlaying: Bool = false
    
    private var currentUrl: URL?
    private var currentStreamId: String?
    private var positionSaveTimer: Timer?
    
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
        
        player.stop()
        player.media = nil
        currentUrl = nil
        currentStreamId = nil
        isPlaying = false
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
            player.currentAudioTrackIndex = indexes[index]
            print("DEBUG: Selected audio track index: \(indexes[index])")
        }
    }
    
    func selectSubtitleTrack(index: Int) {
        if index == -1 {
            // Disable subtitles
            player.currentVideoSubTitleIndex = -1
            print("DEBUG: Disabled subtitles")
        } else if let indexes = player.videoSubTitlesIndexes as? [Int32],
                  index >= 0 && index < indexes.count {
            player.currentVideoSubTitleIndex = indexes[index]
            print("DEBUG: Selected subtitle track index: \(indexes[index])")
        }
    }
}

// MARK: - VLCMediaPlayerDelegate
extension PlayerManager: VLCMediaPlayerDelegate {
    nonisolated func mediaPlayerStateChanged(_ notification: Notification) {
        Task { @MainActor in
            isPlaying = player.isPlaying
        }
    }
}
