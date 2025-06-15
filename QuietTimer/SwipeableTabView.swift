import SwiftUI

struct SwipeableTabView: View {
    @EnvironmentObject var timerStorage: TimerStorage
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Content area with swipe gesture
            TabView(selection: $selectedTab) {
                TimerView()
                    .tag(0)
                
                SavedTimersView()
                    .tag(1)
                
                SettingsView()
                    .tag(2)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Custom tab bar
            HStack {
                Button(action: { selectedTab = 0 }) {
                    VStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 20))
                        Text("Timer")
                            .font(.caption)
                    }
                    .foregroundColor(selectedTab == 0 ? .white : .gray)
                }
                .frame(maxWidth: .infinity)
                
                Button(action: { selectedTab = 1 }) {
                    VStack(spacing: 4) {
                        Image(systemName: "list.number")
                            .font(.system(size: 20))
                        Text("History")
                            .font(.caption)
                    }
                    .foregroundColor(selectedTab == 1 ? .white : .gray)
                }
                .frame(maxWidth: .infinity)
                
                Button(action: { selectedTab = 2 }) {
                    VStack(spacing: 4) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 20))
                        Text("Settings")
                            .font(.caption)
                    }
                    .foregroundColor(selectedTab == 2 ? .white : .gray)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 8)
            .padding(.bottom, 20)
            .background(Color.black)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .ignoresSafeArea(.all, edges: .bottom)
    }
}

#Preview {
    SwipeableTabView()
        .environmentObject(TimerStorage())
} 
