import Foundation

struct TimerSession: Codable, Identifiable {
    let id = UUID()
    var startTime: Date
    var endTime: Date
    var duration: TimeInterval
    var description: String
    
    init(startTime: Date, endTime: Date, description: String = "") {
        self.startTime = startTime
        self.endTime = endTime
        self.duration = endTime.timeIntervalSince(startTime)
        self.description = description
    }
    
    // Helper method to update duration when times change
    mutating func updateDuration() {
        self.duration = endTime.timeIntervalSince(startTime)
    }
    
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    var formattedStartTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: startTime)
    }
} 