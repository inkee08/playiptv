import SwiftUI

struct FullScreenWindowModifier: ViewModifier {
    @Binding var isFullscreen: Bool
    
    @State private var window: NSWindow?
    
    func body(content: Content) -> some View {
        content
            .background(WindowAccessor(window: $window))
            .onChange(of: window) { _, newWindow in
                print("DEBUG: FullScreenModifier captured window: \(String(describing: newWindow))")
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEnterFullScreenNotification)) { notification in
                let notifyWindow = notification.object as? NSWindow
                print("DEBUG: didEnterFullScreen notification from: \(String(describing: notifyWindow)) | Target: \(String(describing: window))")
                if let notifyWindow = notifyWindow, notifyWindow == window {
                    print("DEBUG: Window MATCH. Setting isFullscreen = true")
                    isFullscreen = true
                } else {
                    print("DEBUG: Window MISMATCH or Nil.")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { notification in
                let notifyWindow = notification.object as? NSWindow
                print("DEBUG: didExitFullScreen notification from: \(String(describing: notifyWindow)) | Target: \(String(describing: window))")
                if let notifyWindow = notifyWindow, notifyWindow == window {
                    print("DEBUG: Window MATCH. Setting isFullscreen = false")
                    isFullscreen = false
                }
            }
    }
}

extension View {
    func handleWindowFullscreen(isFullscreen: Binding<Bool>) -> some View {
        self.modifier(FullScreenWindowModifier(isFullscreen: isFullscreen))
    }
}
