import SwiftUI

struct SidebarView: View {
    @Bindable var appState: AppState
    
    @Environment(\.openSettings) private var openSettings
    
    var body: some View {
        List(selection: $appState.selectedCategory) {
            Button(action: {
                appState.selectedCategory = nil
            }) {
                Label("All Channels", systemImage: "square.grid.2x2")
            }
            .buttonStyle(.plain) // Make it look like a list item
            
            Section("Categories") {
                ForEach(appState.categories) { category in
                    NavigationLink(value: category) {
                        Label(category.name, systemImage: iconFor(category.type))
                    }
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 250)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
                    Picker("Source", selection: $appState.currentSource) {
                        ForEach(appState.sources) { source in
                            Text(source.name).tag(Optional(source))
                        }
                    }
                    .pickerStyle(.inline)
                    
                    Divider()
                    
                    Button("Manage Sources...") {
                        appState.settingsTab = .sources
                        Task { try? await openSettings() }
                    }
                } label: {
                    Label("Sources", systemImage: "server.rack")
                }
            }
        }

        .onChange(of: appState.currentSource) { oldValue, newValue in
            if let source = newValue, source.id != oldValue?.id {
                Task {
                    await appState.loadSource(source)
                }
            }
        }
    }
    
    func iconFor(_ type: CategoryType) -> String {
        switch type {
        case .live: return "tv"
        case .movie: return "film"
        case .series: return "play.tv"
        }
    }
}
