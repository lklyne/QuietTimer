//
//  TimerView.swift
//  QuietTimer
//
//  Created by Lyle Klyne on 6/13/25.
//

import SwiftUI
import AVFoundation

struct TimerView: View {
    @State private var timeElapsed: TimeInterval = 0
    @State private var isRunning = false
    @State private var timer: Timer?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var sessionStartTime: Date?
    @State private var timerStartTime: Date? // Track when timer actually started
    @EnvironmentObject var timerStorage: TimerStorage
    
    // Animation states
    @State private var isAnimating = false
    @State private var savedTime: TimeInterval = 0
    @State private var showSavedTimer = false
    @State private var savedTimerAnimated = false
    @State private var showNewTimer = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Main timer area
                Color.black
                    .ignoresSafeArea()
                    .onTapGesture {
                        if !isAnimating {
                            toggleTimer()
                        }
                    }
                
                // Current timer (hidden during save animation)
                Text(formatTime(timeElapsed))
                    .foregroundColor(isRunning ? .gray : .white)
                    .font(.system(size: isRunning ? 24 : 24, weight: .medium, design: .monospaced))
                    .contentTransition(.numericText())
                    .opacity(showSavedTimer ? 0 : 1)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isRunning)
                
                // Saved timer animating out
                if showSavedTimer {
                    Text(formatTime(savedTime))
                        .foregroundColor(.white)
                        .font(.system(size: 24, weight: .medium, design: .monospaced))
                        .offset(
                            x: savedTimerAnimated ? (geometry.size.width * 0.8) : 0,
                            y: savedTimerAnimated ? (geometry.size.height * 1.1) : 0
                        )
                        .scaleEffect(savedTimerAnimated ? 0.4 : 1.0)
                        .opacity(savedTimerAnimated ? 0.0 : 1.0)

                }
                
                // New timer animating in
                if showNewTimer {
                    Text("00:00:00")
                        .foregroundColor(.white)
                        .font(.system(size: 24, weight: .medium, design: .monospaced))
                        .transition(
                            .scale(scale: 0.8)
                            .combined(with: .opacity)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2))
                        )
                }
                
                // Bottom buttons overlay
                if !isRunning && timeElapsed > 0 && !isAnimating {
                    VStack {
                        Spacer()
                        
                        HStack(spacing: 24) {
                            Button("RESET") {
                                resetTimer()
                            }
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.gray.opacity(0.2))
                            )
                            
                            Button("SAVE") {
                                saveCurrentSession()
                            }
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.gray.opacity(0.2))
                            )
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            syncTimerFromBackground()
        }
    }
    
    private func toggleTimer() {
        if isRunning {
            pauseTimer()
        } else {
            startTimer()
        }
    }
    
    private func startTimer() {
        isRunning = true
        
        // Only set session start time if this is a new session
        if sessionStartTime == nil {
            sessionStartTime = Date()
        }
        
        // Calculate the new timer start time based on elapsed time
        timerStartTime = Date().addingTimeInterval(-timeElapsed)
        
        // Use a more frequent timer for better accuracy
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            updateTimeFromStart()
        }
        
        startAudio()
    }
    
    private func pauseTimer() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        // Don't reset timerStartTime - keep it for resume calculation
        stopAudio()
    }
    
    private func resetTimer() {
        timeElapsed = 0
        isRunning = false
        sessionStartTime = nil
        timerStartTime = nil
        timer?.invalidate()
        timer = nil
        stopAudio()
        
        // Reset animation states
        isAnimating = false
        showSavedTimer = false
        showNewTimer = false
        savedTimerAnimated = false
        savedTime = 0
    }
    
    private func updateTimeFromStart() {
        guard let startTime = timerStartTime else { return }
        withAnimation(.easeInOut(duration: 0.05)) {
            timeElapsed = Date().timeIntervalSince(startTime)
        }
    }
    
    private func syncTimerFromBackground() {
        // Sync timer when app returns from background
        if isRunning {
            updateTimeFromStart()
        }
    }
    
    private func saveCurrentSession() {
        guard let startTime = sessionStartTime else { return }
        
        isAnimating = true
        savedTime = timeElapsed
        
        // Step 1: Show saved timer at center
        withAnimation(.easeInOut(duration: 0.2)) {
            showSavedTimer = true
        }
        savedTimerAnimated = false
        
        // Step 2: Main animation toward bottom-right (spring from windup position)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 1.2, dampingFraction: 0.4)) {
                savedTimerAnimated = true
            }
        }
        
        // Step 3: Hide saved timer after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showSavedTimer = false
            }
            savedTimerAnimated = false
            
            // Save session and reset timer state
            let endTime = Date()
            let session = TimerSession(startTime: startTime, endTime: endTime)
            timerStorage.saveSession(session)
            
            // Reset timer state
            timeElapsed = 0
            isRunning = false
            sessionStartTime = nil
            timerStartTime = nil
            timer?.invalidate()
            timer = nil
            stopAudio()
            
            // Step 4: Show new timer
            withAnimation {
                showNewTimer = true
            }
            
            // Step 5: Clean up and re-enable interactions
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                showNewTimer = false
                isAnimating = false
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = Int(time) % 3600 / 60
        let seconds = Int(time) % 60
        
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    private func startAudio() {
        guard let soundURL = Bundle.main.url(forResource: "timer_sound", withExtension: "mp3") else {
            print("Could not find timer_sound.mp3 in bundle")
            return
        }
        
        do {
            // Configure audio session for background playback
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
            
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.numberOfLoops = -1 // Loop indefinitely
            audioPlayer?.volume = 0.5
            audioPlayer?.play()
        } catch {
            print("Error playing audio: \(error)")
        }
    }
    
    private func stopAudio() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
}

#Preview {
    TimerView()
        .environmentObject(TimerStorage())
} 