import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 1 // 默认选中“场馆”页面
    
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground() // 彻底移除系统 TabBar 的背景、毛玻璃和分隔线，确保下方透明
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("首页", systemImage: "house", value: 0) {
                HomeView()
            }
            
            Tab("场馆", systemImage: "dumbbell.fill", value: 1) {
                VenuesView()
            }
            
            Tab("赛事", systemImage: "calendar", value: 2) {
                CalendarView()
            }
            
            Tab("工具", systemImage: "wrench.and.screwdriver", value: 3) {
                ToolsView()
            }
        }
        .preferredColorScheme(.dark)
        .toolbarBackground(.hidden, for: .tabBar) // 全局隐藏系统 TabBar 的毛玻璃背景，防止与自定义抽屉背景重合产生“双层”效果
    }
}

#Preview {
    ContentView()
}
