import SwiftUI
import UIKit

struct ContentView: View {
    @State private var currentTab: String = "home" // "home", "venues", "calendar", "tools"
    @State private var toolSubTab: Int = 0 // 0: sub1, 1: sub2, 2: sub3
    
    // 手势与起降（Lift）状态跟踪
    @State private var isDraggingMain: Bool = false
    @State private var isDraggingTool: Bool = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // 页面容器 (忽略安全区，使底层视图延伸到屏幕边缘)
            TabView(selection: $currentTab) {
                // 1. 首页占位
                NavigationView {
                    VStack(spacing: 20) {
                        Image(systemName: "house")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("首页开发中...")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .navigationTitle("首页")
                    .navigationBarTitleDisplayMode(.inline)
                }
                .toolbar(.hidden, for: .tabBar)
                .tag("home")
                
                // 2. 场馆
                VenuesView()
                    .toolbar(.hidden, for: .tabBar)
                    .tag("venues")
                
                // 3. 赛事占位
                NavigationView {
                    VStack(spacing: 20) {
                        Image(systemName: "calendar")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("赛事日历开发中...")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .navigationTitle("赛事")
                    .navigationBarTitleDisplayMode(.inline)
                }
                .toolbar(.hidden, for: .tabBar)
                .tag("calendar")
                
                // 4. 工具子页面 (根据 toolSubTab 切换显示不同的工具占位)
                Group {
                    switch toolSubTab {
                    case 0:
                        toolPlaceholderView(title: "功能一")
                    case 1:
                        toolPlaceholderView(title: "功能二")
                    case 2:
                        toolPlaceholderView(title: "功能三")
                    default:
                        EmptyView()
                    }
                }
                .toolbar(.hidden, for: .tabBar)
                .tag("tools")
            }
            .ignoresSafeArea(edges: .bottom)
            
            // Telegram 同款：_UILiquidLensView 液态透镜双胶囊 TabBar
            liquidGlassDoubleTabBar
        }
        .preferredColorScheme(.dark)
    }
    
    private func toolPlaceholderView(title: String) -> some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                Text("\(title) 开发中...")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    /// 双胶囊 TabBar 结构：左右镜像尺寸切换（左侧主功能，右侧工具）
    private var liquidGlassDoubleTabBar: some View {
        let isTools = currentTab == "tools"
        
        return HStack(spacing: 12) {
            // 1. 主功能胶囊 (在左边，展开 240pt / 折叠 60pt)
            mainCapsule(isTools: isTools)
            
            // 2. 工具胶囊 (在右边，折叠 60pt / 展开 240pt)
            toolsCapsule(isTools: isTools)
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: isTools)
        .shadow(color: Color.black.opacity(0.45), radius: 12, x: 0, y: 6)
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }
    
    /// 主功能胶囊 (首页、场馆、赛事)
    private func mainCapsule(isTools: Bool) -> some View {
        let mainTabIndex = currentTab == "home" ? 0 : (currentTab == "venues" ? 1 : 2)
        
        // 主胶囊滑块 Selection Frame 计算
        let mainSelectionFrame: CGRect = {
            if isTools {
                // 折叠态：主胶囊缩为圆形 home 键，高亮居中
                return CGRect(x: 4, y: 4, width: 60 - 8, height: 60 - 8)
            } else {
                // 展开态：宽度 240 分为 3 份，每份 80
                return CGRect(x: CGFloat(mainTabIndex) * 80.0 + 4.0, y: 4.0, width: 80.0 - 8.0, height: 60.0 - 8.0)
            }
        }()
        
        return ZStack(alignment: .leading) {
            // 展开态（isTools == false）时，才加载 iOS 26 原生私有透镜滑块
            if !isTools {
                LiquidLensViewRepresentable(selectionFrame: mainSelectionFrame, isLifted: isDraggingMain)
                    .frame(width: 240, height: 60)
            }
            
            HStack(spacing: 0) {
                if isTools {
                    // 折叠态：仅显示 Home 图标
                    tabItem(systemImage: "house.fill", title: "", isSelected: false)
                        .frame(width: 60, height: 60)
                } else {
                    // 展开态
                    tabItem(systemImage: "house.fill", title: "首页", isSelected: mainTabIndex == 0)
                        .frame(width: 80, height: 60)
                    tabItem(systemImage: "mappin.and.ellipse", title: "场馆", isSelected: mainTabIndex == 1)
                        .frame(width: 80, height: 60)
                    tabItem(systemImage: "calendar", title: "赛事", isSelected: mainTabIndex == 2)
                        .frame(width: 80, height: 60)
                }
            }
        }
        .frame(width: isTools ? 60 : 240, height: 60)
        .glassEffect(.regular)
        .clipShape(Capsule())
        .scaleEffect(isDraggingMain ? 0.95 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isDraggingMain)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    isDraggingMain = true
                    if !isTools {
                        let x = value.location.x
                        let index = max(0, min(2, Int(x / 80.0)))
                        let tabs = ["home", "venues", "calendar"]
                        if tabs[index] != currentTab {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                                currentTab = tabs[index]
                            }
                        }
                    } else {
                        // 折叠态下按压或拖动主胶囊直接切回 Home
                        if currentTab != "home" {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                                currentTab = "home"
                            }
                        }
                    }
                }
                .onEnded { _ in
                    isDraggingMain = false
                }
        )
    }
    
    /// 工具胶囊 (功能一、功能二、功能三)
    private func toolsCapsule(isTools: Bool) -> some View {
        let toolSelectionFrame: CGRect = {
            if isTools {
                // 展开态：宽度 240 分为 3 份，每份 80
                return CGRect(x: CGFloat(toolSubTab) * 80.0 + 4.0, y: 4.0, width: 80.0 - 8.0, height: 60.0 - 8.0)
            } else {
                return CGRect(x: 4, y: 4, width: 60 - 8, height: 60 - 8)
            }
        }()
        
        return ZStack(alignment: .leading) {
            // 展开态（isTools == true）时，才加载 iOS 26 原生私有透镜滑块
            if isTools {
                LiquidLensViewRepresentable(selectionFrame: toolSelectionFrame, isLifted: isDraggingTool)
                    .frame(width: 240, height: 60)
            }
            
            HStack(spacing: 0) {
                if isTools {
                    // 展开态：三功能子 Tab
                    tabItem(systemImage: "wrench.and.screwdriver.fill", title: "功能一", isSelected: toolSubTab == 0)
                        .frame(width: 80, height: 60)
                    tabItem(systemImage: "chart.bar.fill", title: "功能二", isSelected: toolSubTab == 1)
                        .frame(width: 80, height: 60)
                    tabItem(systemImage: "gauge", title: "功能三", isSelected: toolSubTab == 2)
                        .frame(width: 80, height: 60)
                } else {
                    // 折叠态：单个工具标志
                    tabItem(systemImage: "wrench.and.screwdriver.fill", title: "", isSelected: false, tintColor: Theme.brandPrimary)
                        .frame(width: 60, height: 60)
                }
            }
        }
        .frame(width: isTools ? 240 : 60, height: 60)
        .glassEffect(.regular)
        .clipShape(Capsule())
        .scaleEffect(isDraggingTool ? 0.95 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isDraggingTool)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    isDraggingTool = true
                    if isTools {
                        let x = value.location.x
                        let index = max(0, min(2, Int(x / 80.0)))
                        if index != toolSubTab {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                                toolSubTab = index
                            }
                        }
                    } else {
                        // 折叠态下按压直接展开并进入工具页面
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.76)) {
                            currentTab = "tools"
                            toolSubTab = 0
                        }
                    }
                }
                .onEnded { _ in
                    isDraggingTool = false
                }
        )
    }
    
    /// 单个 Tab Item 样式
    private func tabItem(systemImage: String, title: String, isSelected: Bool, tintColor: Color? = nil) -> some View {
        VStack(spacing: 3) {
            Image(systemName: systemImage)
                .font(.system(size: 18))
                .foregroundColor(isSelected ? .white : (tintColor ?? .white.opacity(0.45)))
            
            if !title.isEmpty {
                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.45))
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Telegram 同款：UIVisualEffectView + CAFilter (ColorMatrix) 静止背景
private final class RestingBackgroundView: UIVisualEffectView {
    init() {
        let effect = UIBlurEffect(style: .light)
        super.init(effect: effect)
        
        // 隐藏系统默认的次级视图层
        for subview in self.subviews {
            if subview.description.contains("VisualEffectSubview") {
                subview.isHidden = true
            }
        }
        self.clipsToBounds = true
        self.layer.cornerRadius = 26
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Telegram 同款 ColorMatrix 色彩矩阵滤镜，生成质感极其柔和的磨砂底色
    func update(isDark: Bool) {
        guard let sublayers = self.layer.sublayers, !sublayers.isEmpty else { return }
        let sublayer = sublayers[0]
        sublayer.backgroundColor = nil
        sublayer.isOpaque = false
        
        if let classValue = NSClassFromString("CAFilter") as AnyObject as? NSObjectProtocol {
            let makeSelector = NSSelectorFromString("filterWithName:")
            if let filter = classValue.perform(makeSelector, with: "colorMatrix").takeUnretainedValue() as? NSObject {
                // Telegram 专有矩阵参数配置
                var matrix: [Float32] = isDark ?
                    [1.082, -0.113, -0.011, 0.0, 0.135, -0.034, 1.003, -0.011, 0.0, 0.135, -0.034, -0.113, 1.105, 0.0, 0.135, 0.0, 0.0, 0.0, 1.0, 0.0] :
                    [1.185, -0.05, -0.005, 0.0, -0.2, -0.015, 1.15, -0.005, 0.0, -0.2, -0.015, -0.05, 1.195, 0.0, -0.2, 0.0, 0.0, 0.0, 1.0, 0.0]
                filter.setValue(NSValue(bytes: &matrix, objCType: "{CAColorMatrix=ffffffffffffffffffff}"), forKey: "inputColorMatrix")
                sublayer.filters = [filter]
                sublayer.setValue(1.0, forKey: "scale")
            }
        }
    }
}

// MARK: - iOS 26 _UILiquidLensView 桥接包装
struct LiquidLensViewRepresentable: View {
    let selectionFrame: CGRect
    let isLifted: Bool
    
    var body: some View {
        if NSClassFromString("_UILiquidLensView") != nil {
            UILiquidLensRepresentable(selectionFrame: selectionFrame, isLifted: isLifted)
        } else {
            // 低版本 iOS 降级安全策略
            Capsule()
                .fill(Color.white.opacity(0.12))
                .frame(width: selectionFrame.width, height: selectionFrame.height)
                .offset(x: selectionFrame.minX, y: selectionFrame.minY)
                .animation(.spring(response: 0.35, dampingFraction: 0.72), value: selectionFrame)
        }
    }
}

struct UILiquidLensRepresentable: UIViewRepresentable {
    let selectionFrame: CGRect
    let isLifted: Bool
    
    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.isUserInteractionEnabled = false
        
        // 动态反射 iOS 26 内建的 UILiquidLensView 视图
        if let viewClass = NSClassFromString("_UILiquidLensView") as AnyObject as? NSObjectProtocol {
            let allocSelector = NSSelectorFromString("alloc")
            let initSelector = NSSelectorFromString("initWithRestingBackground:")
            
            // 完美集成 Telegram 的 RestingBackgroundView + ColorMatrix 滤镜
            let restingBg = RestingBackgroundView()
            restingBg.update(isDark: true)
            
            let objcAlloc = viewClass.perform(allocSelector).takeUnretainedValue()
            let instance = objcAlloc.perform(initSelector, with: restingBg).takeUnretainedValue()
            if let lensView = instance as? UIView {
                // 启用液态水滴扭曲与起降偏振
                lensView.perform(NSSelectorFromString("setWarpsContentBelow:"), with: true)
                lensView.perform(NSSelectorFromString("setStyle:"), with: NSNumber(value: 1))
                lensView.perform(NSSelectorFromString("setLiftedContentMode:"), with: NSNumber(value: 1))
                
                // 设置常态下透镜镜片的基础蒙版颜色
                lensView.setValue(UIColor(white: 1.0, alpha: 0.12), forKey: "restingBackgroundColor")
                
                // 显式触发初始 resting 布局状态
                let selector = NSSelectorFromString("setLifted:animated:alongsideAnimations:completion:")
                if lensView.responds(to: selector) {
                    typealias ObjCMethod = @convention(c) (AnyObject, Selector, Bool, Bool, @escaping () -> Void, (() -> Void)?) -> Void
                    let method = lensView.method(for: selector)
                    let function = unsafeBitCast(method, to: ObjCMethod.self)
                    function(lensView, selector, false, false, {}, nil)
                }
                
                context.coordinator.lensView = lensView
                container.addSubview(lensView)
            }
        }
        return container
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        guard let lensView = context.coordinator.lensView else { return }
        
        let frame = selectionFrame
        // 当按压/起动（isLifted = true）时，滑块边缘稍微膨胀 4px 实现立体镜片扩张
        let liftedInset: CGFloat = isLifted ? 4.0 : 0.0
        let lensBounds = CGRect(origin: .zero, size: CGSize(width: frame.width + liftedInset * 2.0, height: frame.height + liftedInset * 2.0))
        let lensCenter = CGPoint(x: frame.midX, y: frame.midY)
        
        UIView.animate(withDuration: 0.35, delay: 0, options: [.curveEaseInOut], animations: {
            lensView.bounds = lensBounds
            lensView.center = lensCenter
        })
        
        // 触发物理指压起降切换
        if context.coordinator.isLifted != isLifted {
            context.coordinator.isLifted = isLifted
            let selector = NSSelectorFromString("setLifted:animated:alongsideAnimations:completion:")
            if lensView.responds(to: selector) {
                typealias ObjCMethod = @convention(c) (AnyObject, Selector, Bool, Bool, @escaping () -> Void, (() -> Void)?) -> Void
                let method = lensView.method(for: selector)
                let function = unsafeBitCast(method, to: ObjCMethod.self)
                function(lensView, selector, isLifted, true, {}, nil)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var lensView: UIView?
        var isLifted: Bool = false
    }
}

#Preview {
    ContentView()
}
