import SwiftUI

struct AboutSettingsView: View {
    @Bindable var appState: AppState
    @ObservedObject private var updateChecker = UpdateChecker.shared
    
    var body: some View {
        VStack(spacing: 20) {
            // App Icon and Name
            VStack(spacing: 12) {
                if let appIcon = NSImage(named: "AppIcon") {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 100, height: 100)
                        .cornerRadius(20)
                } else {
                    Image(systemName: "tv.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                }
                
                Text("PlayIPTV")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Version \(updateChecker.currentVersion)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            
            Spacer()
            
            // Update Check Section
            GroupBox {
                VStack(spacing: 12) {
                    if updateChecker.isChecking {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Checking for updates...")
                                .foregroundColor(.secondary)
                        }
                    } else if let error = updateChecker.checkError {
                        Text("Error: \(error)")
                            .foregroundColor(.red)
                            .font(.caption)
                    } else if updateChecker.isUpdateAvailable() {
                        Text("Update available: \(updateChecker.latestRelease?.tagName ?? "")")
                            .foregroundColor(.green)
                            .font(.caption)
                    } else if updateChecker.latestRelease != nil {
                        Text("You're up to date!")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    
                    Button(action: {
                        Task {
                            await updateChecker.checkForUpdates()
                            if updateChecker.isUpdateAvailable() {
                                appState.showUpdateDialog = true
                            }
                        }
                    }) {
                        Text("Check for Updates")
                    }
                    .disabled(updateChecker.isChecking)
                }
                .padding()
            }
            
            Spacer()
            
            // Footer
            VStack(spacing: 8) {
                Text("© 2025 PlayIPTV")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Link("View on GitHub", destination: URL(string: "https://github.com/inkee08/playiptv")!)
                    .font(.caption)
            }
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
