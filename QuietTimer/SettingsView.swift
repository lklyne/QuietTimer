import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var timerStorage: TimerStorage
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 40) {
                VStack(alignment: .leading, spacing: 20) {
                    Text("AUDIO")
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                        .opacity(0.5)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(AudioOption.allCases, id: \.self) { option in
                            AudioOptionRow(
                                title: option.displayName,
                                isSelected: timerStorage.selectedAudioOption == option,
                                action: { timerStorage.selectedAudioOption = option }
                            )
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
    }
}

struct AudioOptionRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Rectangle()
                    .fill(isSelected ? Color.white : Color.clear)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Rectangle()
                            .stroke(Color.white, lineWidth: 1)
                    )
                
                Text(title)
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                
                Spacer()
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    SettingsView()
        .environmentObject(TimerStorage())
} 