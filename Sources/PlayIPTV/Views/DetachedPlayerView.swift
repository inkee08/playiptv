import SwiftUI

struct DetachedPlayerView: View {
    @Bindable var appState: AppState
    // @Environment(\.dismiss) var dismiss -- Not used in manual window
    @FocusState private var isPlayerFocused: Bool
    @State private var isFullscreen: Bool = false
    
    private func closeWindow() {
        DetachedWindowManager.shared.close()
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let channel = appState.detachedChannel {
                if isFullscreen {
                    // Fullscreen layout with side-by-side channel browser
                    ZStack(alignment: .topLeading) {
                        // Main content
                        HStack(spacing: 0) {
                            // Channel Browser (Leading)
                            if appState.isChannelBrowserVisible {
                                FullscreenChannelBrowserView(appState: appState)
                                    .frame(width: 320)
                                    .transition(.move(edge: .leading))
                            }
                            
                            // Video Player
                            PlayerView(url: channel.streamUrl, appState: appState, isFullscreen: $isFullscreen)
                                .focused($isPlayerFocused)
                                .onAppear {
                                    isPlayerFocused = true
                                    // Initialize browser visibility - start hidden
                                    appState.isChannelBrowserVisible = false
                                }
                        }
                        
                        // Toggle button - on top of everything
                        Button(action: {
                            withAnimation {
                                appState.isChannelBrowserVisible.toggle()
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(.black.opacity(0.8))
                                    .frame(width: 44, height: 44)
                                
                                Text(appState.isChannelBrowserVisible ? "◀" : "▶")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                        .help(appState.isChannelBrowserVisible ? "Hide Channels" : "Show Channels")
                        .padding(.leading, appState.isChannelBrowserVisible ? 340 : 20)
                        .padding(.top, 20)
                    }
                } else {
                    // Windowed mode
                    PlayerView(url: channel.streamUrl, appState: appState, isFullscreen: $isFullscreen)
                        .focused($isPlayerFocused)
                        .onAppear { isPlayerFocused = true }
                    
                    // Windowed Controls (Top Right)
                    VStack {
                        HStack(spacing: 15) {
                            Spacer()
                            
                            Button(action: {
                                print("DEBUG: Detached Overlay Button Pressed. KeyWindow: \(String(describing: NSApp.keyWindow))")
                                NSApp.keyWindow?.toggleFullScreen(nil)
                            }) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.white.opacity(0.8))
                                    .background(Circle().fill(Color.black.opacity(0.4)).frame(width: 36, height: 36))
                            }
                            .buttonStyle(.plain)
                            .help("Toggle Fullscreen")
                            
                            Button(action: {
                                appState.detachedChannel = nil
                                closeWindow()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.white.opacity(0.8))
                                .background(Circle().fill(Color.black.opacity(0.4)))
                            }
                            .buttonStyle(.plain)
                            .help("Stop Playback")
                        }
                        .padding(20)
                        
                        Spacer()
                    }
                }
            } else {
                ContentUnavailableView("No Stream", systemImage: "tv.slash", description: Text("Select 'Detach' from the main window to play here."))
            }
        }
        .frame(minWidth: 400, minHeight: 300)
        .navigationTitle(isFullscreen ? "" : (appState.detachedChannel?.name ?? "Player"))
        .onChange(of: appState.detachedChannel) { _, newChannel in
            // Close window when channel is cleared (e.g., when switching to attached mode)
            if newChannel == nil {
                closeWindow()
            }
        }
        .handleWindowFullscreen(isFullscreen: $isFullscreen)
    }
}
