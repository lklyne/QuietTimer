import SwiftUI

struct SavedTimersView: View {
    @EnvironmentObject var timerStorage: TimerStorage
    @State private var showingEditTimer = false
    @State private var selectedSession: TimerSession?
    
    private var groupedSessions: [Date: [String: [TimerSession]]] {
        // First group by date, then by description
        let sessionsByDate = Dictionary(grouping: timerStorage.sessions) { session in
            Calendar.current.startOfDay(for: session.startTime)
        }
        
        var result: [Date: [String: [TimerSession]]] = [:]
        for (date, sessions) in sessionsByDate {
            result[date] = Dictionary(grouping: sessions) { session in
                session.description.isEmpty ? "No Description" : session.description
            }
        }
        return result
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
                                VStack(alignment: .leading, spacing: 20) {
                                    // Date header
                                    Text(formatDateHeader(date))
                                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                                        .foregroundColor(.white)
                                        .opacity(0.5)
                                        .padding(.horizontal, 20)
                                    
                                    // Description groups within this date
                                    ForEach((groupedSessions[date] ?? [:]).keys.sorted(), id: \.self) { description in
                                        VStack(alignment: .leading, spacing: 12) {
                                            // Description header (only show if not "No Description")
                                            if description != "No Description" {
                                                Text(description)
                                                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                                                    .foregroundColor(.white)
                                                    .opacity(0.5)
                                                    .padding(.horizontal, 20)
                                            }
                                            
                                            ForEach(groupedSessions[date]?[description] ?? []) { session in
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
                                                .contentShape(Rectangle())
                                                .onTapGesture {
                                                    selectedSession = session
                                                    showingEditTimer = true
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.top, 20)
                    }
                }
            }
            

        }
        .sheet(isPresented: $showingEditTimer) {
            if let session = selectedSession {
                EditTimerBottomSheetView(session: session, isPresented: $showingEditTimer)
                    .environmentObject(timerStorage)
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
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    private func formatDateHeader(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d yyyy"
        return formatter.string(from: date)
    }
}

#Preview {
    SavedTimersView()
        .environmentObject(TimerStorage())
} 