import SwiftUI

struct EditTimerBottomSheetView: View {
    @EnvironmentObject var timerStorage: TimerStorage
    @Binding var isPresented: Bool
    let session: TimerSession
    
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var description: String
    
    init(session: TimerSession, isPresented: Binding<Bool>) {
        self.session = session
        self._isPresented = isPresented
        self._startTime = State(initialValue: session.startTime)
        self._endTime = State(initialValue: session.endTime)
        self._description = State(initialValue: session.description)
    }
    
    // Computed property to get recent descriptions
    private var recentDescriptions: [String] {
        // For debugging - let's always show some test descriptions
        let testDescriptions = ["Nap", "Another", "Work", "Break"]
        
        // Sort all sessions by start time (most recent first)
        let sortedSessions = timerStorage.sessions.sorted { $0.startTime > $1.startTime }
        
        // Extract non-empty descriptions while maintaining order
        var seenDescriptions = Set<String>()
        let descriptions = sortedSessions.compactMap { session -> String? in
            let trimmedDesc = session.description.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedDesc.isEmpty && !seenDescriptions.contains(trimmedDesc) else { return nil }
            seenDescriptions.insert(trimmedDesc)
            return trimmedDesc
        }
        
        // Take the 8 most recent unique descriptions
        let recentUniqueDescriptions = Array(descriptions.prefix(8))
        
        // Return test descriptions if no real ones exist, otherwise return real ones
        return recentUniqueDescriptions.isEmpty ? testDescriptions : recentUniqueDescriptions
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Navigation bar
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
                
                Spacer()
                
                Text("Edit Timer")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("Save") {
                    saveChanges()
                }
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
                .disabled(endTime <= startTime)
                .opacity(endTime <= startTime ? 0.5 : 1.0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            // Drag indicator
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.white.opacity(0.3))
                .frame(width: 36, height: 5)
                
                // Show current timer item being edited with updated values
                VStack(alignment: .leading, spacing: 8) {
                    Text("CURRENT TIMER")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                        .opacity(0.5)
                    
                    HStack {
                        HStack(spacing: 8) {
                            Text(formatTime(startTime))
                                .font(.system(size: 16, weight: .medium, design: .monospaced))
                                .foregroundColor(startTime != session.startTime ? .green : .white)
                            
                            Text("→")
                                .font(.system(size: 16, weight: .medium, design: .monospaced))
                                .foregroundColor(.white)
                            
                            Text(formatTime(endTime))
                                .font(.system(size: 16, weight: .medium, design: .monospaced))
                                .foregroundColor(endTime != session.endTime ? .green : .white)
                        }
                        
                        Spacer()
                        
                        Text(formatDurationHoursMinutes(endTime.timeIntervalSince(startTime)))
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .foregroundColor(endTime.timeIntervalSince(startTime) != session.duration ? .green : .white)
                    }
                }
                .padding(.horizontal, 20)
                
                VStack(spacing: 20) {
                    // Start time with label on same row
                    HStack {
                        Text("START TIME")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                            .opacity(0.7)
                            .frame(width: 100, alignment: .leading)
                        
                        DatePicker("", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(CompactDatePickerStyle())
                            .colorScheme(.dark)
                    }
                    
                    // End time with label on same row
                    HStack {
                        Text("END TIME")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                            .opacity(0.7)
                            .frame(width: 100, alignment: .leading)
                        
                        DatePicker("", selection: $endTime, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(CompactDatePickerStyle())
                            .colorScheme(.dark)
                    }
                    
                    // Description field with label on same line
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("DESCRIPTION")
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                .foregroundColor(.white)
                                .opacity(0.7)
                                .frame(width: 100, alignment: .leading)
                            
                            TextField("Notes...", text: $description)
                                .font(.system(size: 16, weight: .medium, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(8)
                        }
                        
                        // Recent descriptions - aligned with left edge
                        if !recentDescriptions.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(recentDescriptions, id: \.self) { desc in
                                        Button(desc) {
                                            description = desc
                                        }
                                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.white.opacity(0.2))
                                        .cornerRadius(8)
                                    }
                                    Spacer(minLength: 0)
                                }
                            }
                            .frame(height: 32)
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .background(Color.black)
            .preferredColorScheme(.dark)
    }
    
    private func saveChanges() {
        var updatedSession = session
        updatedSession.startTime = startTime
        updatedSession.endTime = endTime
        updatedSession.description = description
        updatedSession.updateDuration()
        
        timerStorage.updateSession(updatedSession)
        isPresented = false
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    private func formatDurationHoursMinutes(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
} 