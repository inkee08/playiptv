import SwiftUI
import AppKit

@MainActor
class DetachedWindowManager {
    static let shared = DetachedWindowManager()
    
    private var windowController: NSWindowController?
    
    func open(appState: AppState) {
        // If already exists, just bring to front
        if let existing = windowController, let window = existing.window {
            window.makeKeyAndOrderFront(nil)
            return
        }
        
        let playerView = DetachedPlayerView(appState: appState)
            .environment(appState) // Ensure environment propogates if needed
        
        // Host the SwiftUI view
        let hostingController = NSHostingController(rootView: playerView)
        
        // Create the Window manually with correct flags
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 450),
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // visual configuration
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.fullScreenPrimary, .managed]
        window.minSize = NSSize(width: 400, height: 300)
        window.center()
        
        window.contentViewController = hostingController
        window.title = "Player"
        
        // Create Controller
        let controller = NSWindowController(window: window)
        controller.window?.delegate = nil // We don't need a delegate, SwiftUI modifiers listen to notifications
        
        self.windowController = controller
        
        controller.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        
        // Cleanup when closed
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
            nonisolated(unsafe) let appStateRef = appState
            Task { @MainActor [weak self] in
                // Clear the detached channel so AppState stops the player
                appStateRef.detachedChannel = nil
                self?.windowController = nil
            }
        }
    }
    
    func close() {
        windowController?.close()
        windowController = nil
    }
}
