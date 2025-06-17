import SwiftUI

struct SwipeableTabView: View {
    @EnvironmentObject var timerStorage: TimerStorage
    @State private var selectedTab = 0
    @State private var orientation = UIDeviceOrientation.unknown
    
    var isLandscape: Bool {
        orientation.isLandscape
    }
    
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
            .allowsHitTesting(!isLandscape || selectedTab == 0) // Only timer tab responsive in landscape
            
            // Custom tab bar - hidden in landscape mode
            if !isLandscape {
                HStack {
                    Button(action: { selectedTab = 0 }) {
                        VStack(spacing: 8) {
                            Image("clock")
                                .renderingMode(.template)
                                .frame(width: 20, height: 20)
                            Text("Timer")
                                .font(.caption)
                        }
                        .foregroundColor(selectedTab == 0 ? .white : .gray)
                    }
                    .frame(maxWidth: .infinity)
                    
                    Button(action: { selectedTab = 1 }) {
                        VStack(spacing: 8) {
                            Image(timerStorage.isSaveAnimationActive ? "folder-open" : "folder")
                                .renderingMode(.template)
                                .frame(width: 20, height: 20)
                            Text("History")
                                .font(.caption)
                        }
                        .foregroundColor(selectedTab == 1 ? .white : .gray)
                    }
                    .frame(maxWidth: .infinity)
                    
                    Button(action: { selectedTab = 2 }) {
                        VStack(spacing: 8) {
                            Image("cog")
                                .renderingMode(.template)
                                .frame(width: 20, height: 20)
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
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .ignoresSafeArea(.all, edges: .bottom)
        .onAppear {
            // Set initial orientation
            orientation = UIDevice.current.orientation
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                orientation = UIDevice.current.orientation
            }
            
            // Force timer tab when entering landscape
            if orientation.isLandscape && selectedTab != 0 {
                withAnimation(.easeInOut(duration: 0.3)) {
                    selectedTab = 0
                }
            }
        }
    }
}

#Preview {
    SwipeableTabView()
        .environmentObject(TimerStorage())
} 
