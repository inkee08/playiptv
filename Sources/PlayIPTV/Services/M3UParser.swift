import Foundation

struct M3UParser {
    
    // Parses raw M3U string into a list of Channels
    static func parse(content: String) async -> [Channel] {
        var channels: [Channel] = []
        let lines = content.components(separatedBy: .newlines)
        
        var currentAttributes: [String: String] = [:]
        var currentTitle: String = ""
        
        for line in lines {
            let coreLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if coreLine.isEmpty { continue }
            
            if coreLine.hasPrefix("#EXTINF:") {
                // Parse attributes
                // Example: #EXTINF:-1 tvg-id="" tvg-name="US: HBO" tvg-logo="http://...",US: HBO
                // This is a naive parser, a robust one is complex.
                // We will try to extract key metadata like group-title and logo.
                
                currentAttributes = parseAttributes(from: coreLine)
                
                // Extract title (everything after the last comma)
                if let commaIndex = coreLine.lastIndex(of: ",") {
                    currentTitle = String(coreLine[coreLine.index(after: commaIndex)...]).trimmingCharacters(in: .whitespaces)
                } else {
                    currentTitle = "Unknown Channel"
                }
                
            } else if !coreLine.hasPrefix("#") {
                // Should be the URL
                if let url = URL(string: coreLine) {
                    let groupTitle = currentAttributes["group-title"] ?? "Uncategorized"
                    let logoString = currentAttributes["tvg-logo"]
                    let logoUrl = logoString != nil ? URL(string: logoString!) : nil
                    let streamId = currentAttributes["tvg-id"] ?? url.absoluteString
                    
                    let channel = Channel(
                        streamId: streamId,
                        name: currentTitle,
                        logoUrl: logoUrl,
                        streamUrl: url,
                        categoryId: groupTitle, // Using group-title as categoryId for M3U
                        groupTitle: groupTitle
                    )
                    channels.append(channel)
                }
                
                // Reset for next
                currentAttributes = [:]
                currentTitle = ""
            }
        }
        
        return channels
    }
    
    // Helper to parse key="value" attributes
    private static func parseAttributes(from line: String) -> [String: String] {
        var attributes: [String: String] = [:]
        
        let pattern = "([a-zA-Z0-9-]+)=\"([^\"]*)\""
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(location: 0, length: line.utf16.count)
            let matches = regex.matches(in: line, options: [], range: range)
            
            for match in matches {
                if match.numberOfRanges >= 3 {
                    // Extract Key
                    if let keyRange = Range(match.range(at: 1), in: line) {
                        let key = String(line[keyRange])
                        // Extract Value
                        if let valueRange = Range(match.range(at: 2), in: line) {
                            let value = String(line[valueRange])
                            attributes[key] = value
                        }
                    }
                }
            }
        } catch {
            print("Regex error: \(error)")
        }
        
        return attributes
    }
}
