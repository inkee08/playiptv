import SwiftUI

struct ResumePlaybackDialog: View {
    let savedPosition: Double
    let onResume: () -> Void
    let onRestart: () -> Void
    
    private var formattedTime: String {
        let hours = Int(savedPosition) / 3600
        let minutes = (Int(savedPosition) % 3600) / 60
        let seconds = Int(savedPosition) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.accentColor)
            
            Text("Resume Playback?")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("You previously watched this at \(formattedTime)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 15) {
                Button("Restart") {
                    onRestart()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
                
                Button("Resume") {
                    onResume()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(30)
        .frame(width: 350)
    }
}
