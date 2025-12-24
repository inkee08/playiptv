import Foundation

/// Parser for XMLTV format EPG data
class XMLTVParser {
    
    /// Parse XMLTV content and return EPG channels with programs
    static func parse(xmlContent: String) async throws -> [EPGChannel] {
        guard let data = xmlContent.data(using: .utf8) else {
            throw EPGError.invalidData
        }
        
        let parser = XMLTVParserDelegate()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser
        
        guard xmlParser.parse() else {
            throw EPGError.parsingFailed
        }
        
        return parser.channels
    }
}

// MARK: - XML Parser Delegate

private class XMLTVParserDelegate: NSObject, XMLParserDelegate {
    var channels: [EPGChannel] = []
    private var channelMap: [String: String] = [:] // id -> display name
    private var programs: [EPGProgram] = []
    
    // Current element tracking
    private var currentElement = ""
    private var currentChannelId = ""
    private var currentChannelName = ""
    private var currentProgramId = ""
    private var currentProgramChannel = ""
    private var currentProgramTitle = ""
    private var currentProgramStart: Date?
    private var currentProgramEnd: Date?
    private var currentProgramDesc = ""
    private var currentProgramCategory = ""
    private var currentText = ""
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        currentText = ""
        
        switch elementName {
        case "channel":
            currentChannelId = attributeDict["id"] ?? ""
            currentChannelName = ""
            
        case "programme":
            currentProgramChannel = attributeDict["channel"] ?? ""
            currentProgramId = UUID().uuidString
            currentProgramTitle = ""
            currentProgramDesc = ""
            currentProgramCategory = ""
            
            // Parse start and stop times
            if let start = attributeDict["start"] {
                currentProgramStart = parseXMLTVDate(start)
            }
            if let stop = attributeDict["stop"] {
                currentProgramEnd = parseXMLTVDate(stop)
            }
            
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch elementName {
        case "display-name":
            if !currentChannelId.isEmpty {
                currentChannelName = trimmed
            }
            
        case "channel":
            if !currentChannelId.isEmpty && !currentChannelName.isEmpty {
                channelMap[currentChannelId] = currentChannelName
            }
            
        case "title":
            currentProgramTitle = trimmed
            
        case "desc":
            currentProgramDesc = trimmed
            
        case "category":
            if currentProgramCategory.isEmpty {
                currentProgramCategory = trimmed
            }
            
        case "programme":
            // Create program if we have required data
            if !currentProgramChannel.isEmpty,
               !currentProgramTitle.isEmpty,
               let start = currentProgramStart,
               let end = currentProgramEnd {
                
                let program = EPGProgram(
                    id: currentProgramId,
                    channelId: currentProgramChannel,
                    title: currentProgramTitle,
                    startTime: start,
                    endTime: end,
                    description: currentProgramDesc.isEmpty ? nil : currentProgramDesc,
                    category: currentProgramCategory.isEmpty ? nil : currentProgramCategory
                )
                programs.append(program)
            }
            
        default:
            break
        }
        
        currentText = ""
    }
    
    func parserDidEndDocument(_ parser: XMLParser) {
        // Group programs by channel
        var channelPrograms: [String: [EPGProgram]] = [:]
        for program in programs {
            channelPrograms[program.channelId, default: []].append(program)
        }
        
        // Create EPGChannel objects
        channels = channelPrograms.map { channelId, programs in
            let displayName = channelMap[channelId] ?? channelId
            let sortedPrograms = programs.sorted { $0.startTime < $1.startTime }
            return EPGChannel(id: channelId, displayName: displayName, programs: sortedPrograms)
        }
    }
    
    /// Parse XMLTV date format (e.g., "20231224203000 +0000")
    private func parseXMLTVDate(_ dateString: String) -> Date? {
        // XMLTV format: YYYYMMDDHHmmss [timezone]
        let components = dateString.split(separator: " ")
        guard let dateComponent = components.first else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"
        
        // Handle timezone if present
        if components.count > 1 {
            let timezone = String(components[1])
            formatter.timeZone = TimeZone(secondsFromGMT: parseTimezoneOffset(timezone))
        } else {
            formatter.timeZone = TimeZone.current
        }
        
        return formatter.date(from: String(dateComponent))
    }
    
    /// Parse timezone offset (e.g., "+0000" -> 0, "-0500" -> -18000)
    private func parseTimezoneOffset(_ offset: String) -> Int {
        guard offset.count >= 5 else { return 0 }
        
        let sign = offset.hasPrefix("-") ? -1 : 1
        let hoursStr = offset.dropFirst().prefix(2)
        let minutesStr = offset.dropFirst(3).prefix(2)
        
        let hours = Int(hoursStr) ?? 0
        let minutes = Int(minutesStr) ?? 0
        
        return sign * (hours * 3600 + minutes * 60)
    }
}

// MARK: - Errors

enum EPGError: Error, LocalizedError {
    case invalidData
    case parsingFailed
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Invalid EPG data"
        case .parsingFailed:
            return "Failed to parse EPG data"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
