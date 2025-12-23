import SwiftUI

struct SidebarView: View {
    @Bindable var appState: AppState
    
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
            Button(action: {
                appState.logout()
            }) {
                Label("Sources", systemImage: "list.bullet.rectangle.portrait")
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
