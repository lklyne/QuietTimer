import SwiftUI

struct EditTimerView: View {
    @EnvironmentObject var timerStorage: TimerStorage
    @Binding var isPresented: Bool
    let session: TimerSession
    
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date()
    @State private var description: String = ""
    
    init(session: TimerSession, isPresented: Binding<Bool>) {
        self.session = session
        self._isPresented = isPresented
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
            
            VStack(spacing: 24) {
                Text("EDIT TIMER")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                
                // Show current timer item being edited
                VStack(alignment: .leading, spacing: 8) {
                    Text("CURRENT TIMER")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                        .opacity(0.5)
                    
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
                    .padding(12)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                }
                
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
                    
                    // Duration display
                    HStack {
                        Text("DURATION")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                            .opacity(0.7)
                            .frame(width: 100, alignment: .leading)
                        
                        Text(formatDuration(endTime.timeIntervalSince(startTime)))
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                        
                        Spacer()
                    }
                    
                    // Description field with label on same line
                    HStack {
                        Text("DESCRIPTION")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                            .opacity(0.7)
                            .frame(width: 100, alignment: .leading)
                        
                        TextField("Add a description...", text: $description)
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                
                HStack(spacing: 16) {
                    Button("CANCEL") {
                        isPresented = false
                    }
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                    
                    Button("SAVE") {
                        saveChanges()
                    }
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundColor(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .cornerRadius(8)
                    .disabled(endTime <= startTime)
                    .opacity(endTime <= startTime ? 0.5 : 1.0)
                }
            }
            .padding(24)
            .background(Color.black)
            .cornerRadius(16)
            .padding(.horizontal, 40)
            .onAppear {
                startTime = session.startTime
                endTime = session.endTime
                description = session.description
            }
        }
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

struct EditTimerBottomSheetView: View {
    @EnvironmentObject var timerStorage: TimerStorage
    @Binding var isPresented: Bool
    let session: TimerSession
    
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date()
    @State private var description: String = ""
    
    init(session: TimerSession, isPresented: Binding<Bool>) {
        self.session = session
        self._isPresented = isPresented
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Drag indicator
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)
                
                // Show current timer item being edited
                VStack(alignment: .leading, spacing: 8) {
                    Text("CURRENT TIMER")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                        .opacity(0.5)
                    
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
                    .padding(12)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
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
                    
                    // Duration display
                    HStack {
                        Text("DURATION")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                            .opacity(0.7)
                            .frame(width: 100, alignment: .leading)
                        
                        Text(formatDuration(endTime.timeIntervalSince(startTime)))
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                        
                        Spacer()
                    }
                    
                    // Description field with label on same line
                    HStack {
                        Text("DESCRIPTION")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                            .opacity(0.7)
                            .frame(width: 100, alignment: .leading)
                        
                        TextField("Add a description...", text: $description)
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .background(Color.black)
            .navigationTitle("Edit Timer")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                }
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundColor(.white),
                
                trailing: Button("Save") {
                    saveChanges()
                }
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
                .disabled(endTime <= startTime)
                .opacity(endTime <= startTime ? 0.5 : 1.0)
            )
        }
        .preferredColorScheme(.dark)
        .onAppear {
            startTime = session.startTime
            endTime = session.endTime
            description = session.description
        }
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