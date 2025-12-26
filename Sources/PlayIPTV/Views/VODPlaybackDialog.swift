import SwiftUI

struct VODPlaybackDialog: View {
    let channel: Channel
    let savedPosition: Double?
    let onPlay: () -> Void
    let onResume: (() -> Void)?
    let onCancel: () -> Void
    
    private var formattedTime: String? {
        guard let position = savedPosition else { return nil }
        let hours = Int(position) / 3600
        let minutes = (Int(position) % 3600) / 60
        let seconds = Int(position) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: savedPosition != nil ? "play.circle.fill" : "play.tv.fill")
                .font(.system(size: 50))
                .foregroundColor(.accentColor)
            
            Text(savedPosition != nil ? "Resume Playback?" : "Play Video?")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                Text(channel.name)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                if let time = formattedTime {
                    Text("Previously watched at \(time)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 15) {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
                
                if savedPosition != nil {
                    Button("Start Over") {
                        onPlay()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Resume") {
                        onResume?()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button("Play") {
                        onPlay()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(30)
        .frame(width: 380)
    }
}
