import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 1 // 默认选中“场馆”页面
    
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground() // 彻底移除系统 TabBar 的背景、毛玻璃和分隔线，确保下方透明
        
        let activeColor = UIColor.white
        let inactiveColor = UIColor.white.withAlphaComponent(0.4) // 对齐小程序暗灰色效果
        
        let layouts = [appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance, appearance.compactInlineLayoutAppearance]
        for layout in layouts {
            layout.normal.iconColor = inactiveColor
            layout.normal.titleTextAttributes = [.foregroundColor: inactiveColor]
            layout.selected.iconColor = activeColor
            layout.selected.titleTextAttributes = [.foregroundColor: activeColor]
        }
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("首页", image: "tab_home", value: 0) {
                HomeView()
            }
            
            Tab("场馆", image: "tab_venue", value: 1) {
                VenuesView()
            }
            
            Tab("赛事", image: "tab_calendar", value: 2) {
                CalendarView()
            }
            
            Tab("工具", image: "tab_tools", value: 3) {
                ToolsView()
            }
        }
        .tint(.white) // 显式设置 TabBar 的 Accent Tint 颜色为白色，防止 MapKit (Map) 激活时将其重置为系统默认蓝色
        .preferredColorScheme(.dark)
        .toolbarBackground(.hidden, for: .tabBar) // 全局隐藏系统 TabBar 的毛玻璃背景，防止与自定义抽屉背景重合产生“双层”效果
    }
}

#Preview {
    ContentView()
}
