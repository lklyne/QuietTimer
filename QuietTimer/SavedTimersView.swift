import SwiftUI

struct SavedTimersView: View {
    @ObservedObject var timerStorage: TimerStorage
    
    private var groupedSessions: [Date: [TimerSession]] {
        Dictionary(grouping: timerStorage.sessions) { session in
            Calendar.current.startOfDay(for: session.startTime)
        }
    }
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                if timerStorage.sessions.isEmpty {
                    VStack(spacing: 20) {
                        Text("No saved timers yet")
                            .font(.system(size: 18, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 36) {
                            ForEach(groupedSessions.keys.sorted(by: >), id: \.self) { date in
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(formatDateHeader(date))
                                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                                        .foregroundColor(.white)
                                        .opacity(0.5)
                                        .padding(.horizontal, 20)
                                    
                                    ForEach(groupedSessions[date] ?? []) { session in
                                        HStack {
                                            HStack(spacing: 8) {
                                                Text(formatTime(session.startTime))
                                                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                                                    .foregroundColor(.white)
                                                
                                                Text("→")
                                                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                                                    .foregroundColor(.white)
                                                
                                                Text(formatTime(session.endTime))
                                                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                                                    .foregroundColor(.white)
                                            }
                                            
                                            Spacer()
                                            
                                            Text(formatDurationHoursMinutes(session.duration))
                                                .font(.system(size: 16, weight: .medium, design: .monospaced))
                                                .foregroundColor(.white)
                                        }
                                        .padding(.horizontal, 20)
                                    }
                                }
                            }
                        }
                        .padding(.top, 20)
                    }
                }
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDurationHoursMinutes(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        return String(format: "%02d:%02d", hours, minutes)
    }
    
    private func formatDateHeader(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d yyyy"
        return formatter.string(from: date)
    }
}

#Preview {
    SavedTimersView(timerStorage: TimerStorage())
} 