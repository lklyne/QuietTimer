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
    @ObservedObject var timerStorage: TimerStorage
    
    var body: some View {
        ZStack {
            // Main timer area
            Color.black
                .ignoresSafeArea()
                .onTapGesture {
                    toggleTimer()
                }
            
            Text(formatTime(timeElapsed))
                .foregroundColor(isRunning ? .gray : .white)
                .font(.system(size: isRunning ? 28 : 24, weight: .medium, design: .monospaced))
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isRunning)
            
            // Top buttons overlay
            if !isRunning && timeElapsed > 0 {
                VStack {
                    HStack(spacing: 24) {
                        Button("Reset") {
                            resetTimer()
                        }
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.black)
                        )
                        
                        Button("Save") {
                            saveCurrentSession()
                        }
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.black)
                        )
                    }
                    .padding(.horizontal)
                    .padding(.top, 0)
                    
                    Spacer()
                }
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
        sessionStartTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            timeElapsed += 1.0
        }
        startAudio()
    }
    
    private func pauseTimer() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        stopAudio()
    }
    
    private func resetTimer() {
        timeElapsed = 0
        isRunning = false
        sessionStartTime = nil
        timer?.invalidate()
        timer = nil
        stopAudio()
    }
    
    private func saveCurrentSession() {
        guard let startTime = sessionStartTime else { return }
        let endTime = Date()
        let session = TimerSession(startTime: startTime, endTime: endTime)
        timerStorage.saveSession(session)
        resetTimer()
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
    TimerView(timerStorage: TimerStorage())
} 