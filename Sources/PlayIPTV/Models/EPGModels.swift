import Foundation

/// Represents a single program in the EPG
struct EPGProgram: Identifiable, Codable {
    let id: String // Unique identifier
    let channelId: String // Reference to EPG channel
    let title: String
    let startTime: Date
    let endTime: Date
    let description: String?
    let category: String?
    
    /// Check if this program is currently airing
    var isCurrentlyAiring: Bool {
        let now = Date()
        return now >= startTime && now < endTime
    }
    
    /// Check if this program is upcoming (starts within next hour)
    var isUpcoming: Bool {
        let now = Date()
        let oneHourFromNow = now.addingTimeInterval(3600)
        return startTime > now && startTime <= oneHourFromNow
    }
    
    /// Formatted time range string (e.g., "8:00 PM - 9:00 PM")
    func timeRangeString() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
    }
}

/// Represents EPG data for a channel
struct EPGChannel: Identifiable, Codable {
    let id: String // EPG channel ID
    let displayName: String
    var programs: [EPGProgram]
    
    /// Get the currently airing program
    func getCurrentProgram() -> EPGProgram? {
        programs.first { $0.isCurrentlyAiring }
    }
    
    /// Get the next upcoming program
    func getNextProgram() -> EPGProgram? {
        let now = Date()
        return programs
            .filter { $0.startTime > now }
            .sorted { $0.startTime < $1.startTime }
            .first
    }
}
