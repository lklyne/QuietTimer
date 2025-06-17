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

class TimerStorage: ObservableObject {
    private let userDefaults = UserDefaults.standard
    private let storageKey = "SavedTimerSessions"
    private let audioSettingKey = "SelectedAudioOption"
    
    @Published var sessions: [TimerSession] = []
    @Published var selectedAudioOption: AudioOption = .pinkNoiseShush {
        didSet {
            saveAudioSetting()
        }
    }
    
    init() {
        loadSessions()
        loadAudioSetting()
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
} 