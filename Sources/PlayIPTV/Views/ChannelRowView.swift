import SwiftUI

/// Optimized channel row view with Equatable to prevent unnecessary updates
struct ChannelRowView: View, Equatable {
    let channel: Channel
    let epgProgram: EPGProgram?
    let isSelected: Bool
    let isFavorited: Bool
    let isLoading: Bool
    let onTap: () -> Void
    let onToggleFavorite: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "tv")
                    .foregroundStyle(.secondary)
                
                Text(channel.name)
                    .lineLimit(1)
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                    Text("Loading...")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                if isFavorited {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
                
                Spacer()
            }
            
            // EPG Program info (Live TV only)
            if let program = epgProgram {
                Text(program.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.leading, 24)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .onTapGesture(perform: onTap)
        .contextMenu {
            Button(action: onToggleFavorite) {
                Label(isFavorited ? "Remove from Favorites" : "Add to Favorites", 
                      systemImage: isFavorited ? "heart.slash" : "heart")
            }
        }
    }
    
    // Equatable conformance - only update if these values change
    static func == (lhs: ChannelRowView, rhs: ChannelRowView) -> Bool {
        lhs.channel.id == rhs.channel.id &&
        lhs.epgProgram?.id == rhs.epgProgram?.id &&
        lhs.isSelected == rhs.isSelected &&
        lhs.isFavorited == rhs.isFavorited &&
        lhs.isLoading == rhs.isLoading
    }
}
