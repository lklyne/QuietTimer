//
//  QuietTimerApp.swift
//  QuietTimer
//
//  Created by Lyle Klyne on 6/13/25.
//

import SwiftUI
import AVFoundation

@main
struct QuietTimerApp: App {
    @StateObject private var timerStorage = TimerStorage()
    
    init() {
        configureAudioSession()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(timerStorage)
                .background(Color.black)
                .preferredColorScheme(.dark)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    // App is going to background
                    handleAppGoingToBackground()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // App is coming to foreground
                    handleAppComingToForeground()
                }
        }
    }
    
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
    
    private func handleAppGoingToBackground() {
        // Audio will continue playing automatically with the configured audio session
        print("App going to background - timer will continue")
    }
    
    private func handleAppComingToForeground() {
        // Sync timer state when returning to foreground
        print("App coming to foreground - syncing timer state")
    }
}
