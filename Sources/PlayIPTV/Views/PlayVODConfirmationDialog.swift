import SwiftUI

struct PlayVODConfirmationDialog: View {
    let channel: Channel
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "play.tv.fill")
                .font(.system(size: 50))
                .foregroundColor(.accentColor)
            
            Text("Play \(channel.isSeries ? "Series" : "Movie")?")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(channel.name)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 15) {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
                
                Button("Play") {
                    onConfirm()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(30)
        .frame(width: 350)
    }
}
