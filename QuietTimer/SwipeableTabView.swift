import SwiftUI

struct SwipeableTabView: View {
    @StateObject private var timerStorage = TimerStorage()
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Content area with swipe gesture
            TabView(selection: $selectedTab) {
                TimerView(timerStorage: timerStorage)
                    .tag(0)
                
                SavedTimersView(timerStorage: timerStorage)
                    .tag(1)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Custom tab bar
            HStack {
                Button(action: { selectedTab = 0 }) {
                    VStack(spacing: 4) {
                        Image(systemName: "timer")
                            .font(.system(size: 20))
                        Text("Timer")
                            .font(.caption)
                    }
                    .foregroundColor(selectedTab == 0 ? .white : .gray)
                }
                .frame(maxWidth: .infinity)
                
                Button(action: { selectedTab = 1 }) {
                    VStack(spacing: 4) {
                        Image(systemName: "list.bullet.clipboard")
                            .font(.system(size: 20))
                        Text("History")
                            .font(.caption)
                    }
                    .foregroundColor(selectedTab == 1 ? .white : .gray)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 8)
            .background(Color.black)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .ignoresSafeArea(.all, edges: .bottom)
    }
}

#Preview {
    SwipeableTabView()
} 