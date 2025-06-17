import Foundation

enum AudioOption: String, CaseIterable, Codable {
    case pinkNoiseShush = "pink_noise_shush"
    case pinkNoise = "pink_noise"
    case noSound = "no_sound"
    
    var displayName: String {
        switch self {
        case .pinkNoiseShush:
            return "PINK NOISE + SHUSH"
        case .pinkNoise:
            return "PINK NOISE"
        case .noSound:
            return "NO SOUND"
        }
    }
    
    var fileName: String? {
        switch self {
        case .pinkNoiseShush:
            return "sound_pink_noise_shush"
        case .pinkNoise:
            return "sound_pink_noise"
        case .noSound:
            return nil
        }
    }
}

enum FadeoutOption: String, CaseIterable, Codable {
    case none = "none"
    case twentySeconds = "20s"
    case fifteenMinutes = "15m"
    case thirtyMinutes = "30m"
    case fortyFiveMinutes = "45m"
    case oneHour = "1h"
    
    var displayName: String {
        switch self {
        case .none:
            return "NONE"
        case .twentySeconds:
            return "20 SECONDS"
        case .fifteenMinutes:
            return "15 MINUTES"
        case .thirtyMinutes:
            return "30 MINUTES"
        case .fortyFiveMinutes:
            return "45 MINUTES"
        case .oneHour:
            return "60 MINUTES"
        }
    }
    
    var durationInSeconds: TimeInterval {
        switch self {
        case .none:
            return 0
        case .twentySeconds:
            return 20
        case .fifteenMinutes:
            return 15 * 60
        case .thirtyMinutes:
            return 30 * 60
        case .fortyFiveMinutes:
            return 45 * 60
        case .oneHour:
            return 60 * 60
        }
    }
}

class TimerStorage: ObservableObject {
    private let userDefaults = UserDefaults.standard
    private let storageKey = "SavedTimerSessions"
    private let audioSettingKey = "SelectedAudioOption"
    private let fadeoutSettingKey = "SelectedFadeoutOption"
    
    @Published var sessions: [TimerSession] = []
    @Published var selectedAudioOption: AudioOption = .pinkNoiseShush {
        didSet {
            saveAudioSetting()
        }
    }
    @Published var selectedFadeoutOption: FadeoutOption = .none {
        didSet {
            saveFadeoutSetting()
        }
    }
    
    init() {
        loadSessions()
        loadAudioSetting()
        loadFadeoutSetting()
    }
    
    func saveSession(_ session: TimerSession) {
        sessions.append(session)
        saveSessions()
    }
    
    func deleteSession(at index: Int) {
        guard index < sessions.count else { return }
        sessions.remove(at: index)
        saveSessions()
    }
    
    func clearAllSessions() {
        sessions.removeAll()
        saveSessions()
    }
    
    private func saveSessions() {
        do {
            let data = try JSONEncoder().encode(sessions)
            userDefaults.set(data, forKey: storageKey)
        } catch {
            print("Failed to save sessions: \(error)")
        }
    }
    
    private func loadSessions() {
        guard let data = userDefaults.data(forKey: storageKey) else {
            sessions = []
            return
        }
        
        do {
            sessions = try JSONDecoder().decode([TimerSession].self, from: data)
        } catch {
            print("Failed to load sessions: \(error)")
            sessions = []
        }
    }
    
    private func saveAudioSetting() {
        do {
            let data = try JSONEncoder().encode(selectedAudioOption)
            userDefaults.set(data, forKey: audioSettingKey)
        } catch {
            print("Failed to save audio setting: \(error)")
        }
    }
    
    private func loadAudioSetting() {
        guard let data = userDefaults.data(forKey: audioSettingKey) else {
            selectedAudioOption = .pinkNoiseShush // Default to pink noise + shush
            return
        }
        
        do {
            selectedAudioOption = try JSONDecoder().decode(AudioOption.self, from: data)
        } catch {
            print("Failed to load audio setting: \(error)")
            selectedAudioOption = .pinkNoiseShush
        }
    }
    
    private func saveFadeoutSetting() {
        do {
            let data = try JSONEncoder().encode(selectedFadeoutOption)
            userDefaults.set(data, forKey: fadeoutSettingKey)
        } catch {
            print("Failed to save fadeout setting: \(error)")
        }
    }
    
    private func loadFadeoutSetting() {
        guard let data = userDefaults.data(forKey: fadeoutSettingKey) else {
            selectedFadeoutOption = .none // Default to no fadeout
            return
        }
        
        do {
            selectedFadeoutOption = try JSONDecoder().decode(FadeoutOption.self, from: data)
        } catch {
            print("Failed to load fadeout setting: \(error)")
            selectedFadeoutOption = .none
        }
    }
} 