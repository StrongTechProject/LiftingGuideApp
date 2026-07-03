import SwiftUI

struct CalendarView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Image(systemName: "calendar")
                        .font(.system(size: 64))
                        .foregroundColor(Theme.textSecondary)
                        .padding()
                    
                    Text("赛事日历开发中...")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.textStrong)
                    
                    Text("这里将展示国内外健力赛事与报名日程。")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
            .navigationTitle("赛事")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
        }
    }
}

#Preview {
    CalendarView()
}
