import SwiftUI

struct MainTabView: View {
    @StateObject private var timerStorage = TimerStorage()
    
    var body: some View {
        TabView {
            TimerView(timerStorage: timerStorage)
                .tabItem {
                    Image(systemName: "timer")
                    Text("Timer")
                }
            
            SavedTimersView(timerStorage: timerStorage)
                .tabItem {
                    Image(systemName: "list.bullet.clipboard")
                    Text("History")
                }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .accentColor(.white)
    }
}

#Preview {
    MainTabView()
} 