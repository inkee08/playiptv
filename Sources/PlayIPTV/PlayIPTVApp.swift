import SwiftUI

@main
struct PlayIPTVApp: App {
    @State private var appState = AppState()

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(appState: appState)
                .environment(appState)
                .onAppear { applyTheme(appState.theme) }
                .onChange(of: appState.theme) { _, newTheme in
                    applyTheme(newTheme)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)
        .windowResizability(.contentMinSize)
        .commands {
            SidebarCommands()
            
            CommandMenu("Playback") {
                Button("Play/Pause") {
                    appState.playPauseSignal.toggle()
                }
                .keyboardShortcut(.space, modifiers: [])
                
                Button("Mute/Unmute") {
                    appState.muteToggleSignal.toggle()
                }
                .keyboardShortcut("m", modifiers: [])
                
                Button("Toggle Fullscreen") {
                    print("DEBUG: 'F' / Menu Item Pressed. KeyWindow: \(String(describing: NSApp.keyWindow))")
                    NSApp.keyWindow?.toggleFullScreen(nil)
                }
                .keyboardShortcut("f", modifiers: [])
            }
        }
        
        Settings {
            SettingsView(appState: appState)
                .environment(appState)
        }
        
        Settings {
            SettingsView(appState: appState)
                .environment(appState)
        }
    }

    private func applyTheme(_ theme: AppState.AppTheme) {
        switch theme {
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .system:
            NSApp.appearance = nil
        }
    }
}
