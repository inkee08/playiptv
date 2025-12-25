import SwiftUI

struct UpdateNotificationView: View {
    let release: GitHubRelease
    let onDownload: () -> Void
    let onSkip: () -> Void
    let onRemindLater: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Icon and title
            VStack(spacing: 12) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Update Available")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Version \(release.tagName)")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            // Release notes
            if let body = release.body, !body.isEmpty {
                ScrollView {
                    Text(body)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(8)
                }
                .frame(maxHeight: 200)
            }
            
            // Buttons
            HStack(spacing: 12) {
                Button("Remind Me Later") {
                    onRemindLater()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Skip This Version") {
                    onSkip()
                }
                
                Button("Download") {
                    onDownload()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(30)
        .frame(width: 500)
    }
}
