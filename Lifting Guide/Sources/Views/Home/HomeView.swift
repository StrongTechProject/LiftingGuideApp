import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 64))
                        .foregroundColor(Theme.textSecondary)
                        .padding()
                    
                    Text("首页开发中...")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.textStrong)
                    
                    Text("这里将展示个性化健力训练推荐与动态。")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
            .navigationTitle("首页")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
        }
    }
}

#Preview {
    HomeView()
}
