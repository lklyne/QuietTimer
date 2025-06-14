import Foundation

class TimerStorage: ObservableObject {
    private let userDefaults = UserDefaults.standard
    private let storageKey = "SavedTimerSessions"
    
    @Published var sessions: [TimerSession] = []
    
    init() {
        loadSessions()
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
} 