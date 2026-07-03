import SwiftUI

struct ToolsView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 64))
                        .foregroundColor(Theme.textSecondary)
                        .padding()
                    
                    Text("健力工具箱开发中...")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.textStrong)
                    
                    Text("包括 Wilks 计算器、重量折算、杠铃弯曲度测量等专业工具。")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
            .navigationTitle("工具")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
        }
    }
}

#Preview {
    ToolsView()
}
