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
    @State private var fadeoutTimer: Timer?
    @State private var orientation = UIDeviceOrientation.unknown
    @EnvironmentObject var timerStorage: TimerStorage
    
    // Animation states
    @State private var isAnimating = false
    @State private var savedTime: TimeInterval = 0
    @State private var showSavedTimer = false
    @State private var savedTimerAnimated = false
    @State private var savedTimerPhase: AnimationPhase = .initial
    @State private var showNewTimer = false
    
    enum AnimationPhase {
        case initial
        case windupUp
        case springDown
    }
    
    var isLandscape: Bool {
        orientation.isLandscape
    }
    
    var timerFontSize: CGFloat {
        isLandscape ? 48 : 24
    }
    
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
                    .font(.system(size: timerFontSize, weight: .medium, design: .monospaced))
                    .contentTransition(.numericText())
                    .opacity(showSavedTimer ? 0 : 1)
                    // .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isRunning)
                    .animation(.easeInOut(duration: 0.3), value: timerFontSize)
                
                // Saved timer animating out
                if showSavedTimer {
                    Text(formatTime(savedTime))
                        .foregroundColor(.white)
                        .font(.system(size: timerFontSize, weight: .medium, design: .monospaced))
                        .offset(
                            y: {
                                switch savedTimerPhase {
                                case .initial:
                                    return 0
                                case .windupUp:
                                    return -geometry.size.height * 0.02 // Move up slightly
                                case .springDown:
                                    return geometry.size.height * 1.75 // Spring down
                                }
                            }()
                        )
                        .scaleEffect({
                            switch savedTimerPhase {
                            case .initial, .windupUp:
                                return 1.0
                            case .springDown:
                                return 0.1
                            }
                        }())
                        .opacity({
                            switch savedTimerPhase {
                            case .initial, .windupUp:
                                return 1.02
                            case .springDown:
                                return 0.0
                            }
                        }())
                }
                
                // New timer animating in
                if showNewTimer {
                    Text("00:00:00")
                        .foregroundColor(.white)
                        .font(.system(size: timerFontSize, weight: .medium, design: .monospaced))
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
                            Button(action: {
                                resetTimer()
                            }) {
                                Text("RESET")
                                    .foregroundColor(.white)
                                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.gray.opacity(0.2))
                                    )
                            }
                            
                            Button(action: {
                                saveCurrentSession()
                            }) {
                                Text("SAVE")
                                    .foregroundColor(.black)
                                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.white.opacity(0.9))
                                    )
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, isLandscape ? 20 : 40)
                    }
                }
            }
        }
        .onAppear {
            // Set initial orientation
            orientation = UIDevice.current.orientation
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                orientation = UIDevice.current.orientation
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            syncTimerFromBackground()
        }
        .onChange(of: timerStorage.selectedAudioOption) { _ in
            // React to audio setting changes while timer is running
            if isRunning {
                stopAudio()
                startAudio()
            }
        }
        .onChange(of: timerStorage.selectedFadeoutOption) { _ in
            // React to fadeout setting changes while timer is running
            if isRunning {
                stopFadeoutTimer()
                startFadeoutTimer()
            }
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
        startFadeoutTimer()
    }
    
    private func pauseTimer() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        // Don't reset timerStartTime - keep it for resume calculation
        stopAudio()
        stopFadeoutTimer()
    }
    
    private func resetTimer() {
        timeElapsed = 0
        isRunning = false
        sessionStartTime = nil
        timerStartTime = nil
        timer?.invalidate()
        timer = nil
        stopAudio()
        stopFadeoutTimer()
        
        // Reset animation states
        isAnimating = false
        showSavedTimer = false
        showNewTimer = false
        savedTimerPhase = .initial
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
        timerStorage.isSaveAnimationActive = true
        
        // Step 1: Show saved timer at center
        withAnimation(.easeInOut(duration: 0.13)) {
            showSavedTimer = true
        }
        savedTimerPhase = .initial
        
        // Step 2: First move up slightly (windup)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.15)) {
                savedTimerPhase = .windupUp
            }
            
            // Step 3: Then spring down (main animation)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.smooth(duration: 0.4)) {
                    savedTimerPhase = .springDown
                }
            }
        }
        
        // Close folder icon early (adjust timing as needed)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            timerStorage.isSaveAnimationActive = false
        }
        
        // Step 3: Hide saved timer after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showSavedTimer = false
            }
            savedTimerPhase = .initial
            
            // Save session and reset timer state
            let endTime = Date()
            let session = TimerSession(startTime: startTime, endTime: endTime, description: "")
            timerStorage.saveSession(session)
            
            // Reset timer state
            timeElapsed = 0
            isRunning = false
            sessionStartTime = nil
            timerStartTime = nil
            timer?.invalidate()
            timer = nil
            stopAudio()
            stopFadeoutTimer()
            
            // Step 4: Show new timer
            withAnimation {
                showNewTimer = true
            }
            
            // Step 5: Clean up and re-enable interactions
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                showNewTimer = false
                isAnimating = false
                // Note: folder icon already closed earlier
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
        // Check if audio file is selected
        guard let fileName = timerStorage.selectedAudioOption.fileName else { return }
        
        guard let soundURL = Bundle.main.url(forResource: fileName, withExtension: "mp3") else {
            print("Could not find \(fileName).mp3 in bundle")
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
    
    private func startFadeoutTimer() {
        // Only start fadeout if a fadeout option is selected and audio is playing
        guard timerStorage.selectedFadeoutOption != .none,
              let audioPlayer = audioPlayer,
              audioPlayer.isPlaying else { return }
        
        let fadeoutDuration = timerStorage.selectedFadeoutOption.durationInSeconds
        let fadeStartTime = fadeoutDuration / 2 // Start fading at halfway point
        
        fadeoutTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            updateFadeout(fadeoutDuration: fadeoutDuration, fadeStartTime: fadeStartTime)
        }
    }
    
    private func stopFadeoutTimer() {
        fadeoutTimer?.invalidate()
        fadeoutTimer = nil
    }
    
    private func updateFadeout(fadeoutDuration: TimeInterval, fadeStartTime: TimeInterval) {
        guard let audioPlayer = audioPlayer else {
            stopFadeoutTimer()
            return
        }
        
        // If we've reached the fadeout duration, stop the audio completely
        if timeElapsed >= fadeoutDuration {
            audioPlayer.volume = 0
            stopAudio()
            stopFadeoutTimer()
            return
        }
        
        // Start fading at the halfway point
        if timeElapsed >= fadeStartTime {
            let fadeProgress = (timeElapsed - fadeStartTime) / (fadeoutDuration - fadeStartTime)
            // Apply ease-in-out curve: starts slow, speeds up in middle, slows down at end
            let easedProgress = fadeProgress < 0.5 
                ? 2 * fadeProgress * fadeProgress 
                : 1 - pow(-2 * fadeProgress + 2, 3) / 2
            let volume = max(0, 0.5 * (1 - easedProgress)) // Fade from 0.5 to 0
            audioPlayer.volume = Float(volume)
        }
    }
}

#Preview {
    TimerView()
        .environmentObject(TimerStorage())
} 
