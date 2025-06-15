import SwiftUI

struct MainTabView: View {
    @StateObject private var timerStorage = TimerStorage()
    
    var body: some View {
        TabView {
            TimerView()
                .tabItem {
                    Image(systemName: "timer")
                    Text("Timer")
                }
            
            SavedTimersView()
                .tabItem {
                    Image(systemName: "list.bullet.clipboard")
                    Text("History")
                }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .accentColor(.white)
        .environmentObject(timerStorage)
    }
}

#Preview {
    MainTabView()
} 