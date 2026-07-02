import SwiftUI
import MapKit
import CoreLocation

/// 场馆页主视图 - iOS 原生重构版 (在 TabBar 上方呈现自定义半屏面板，无遮挡且不影响交互)
struct VenuesView: View {
    @StateObject private var viewModel = VenuesViewModel()
    @State private var selectedVenue: Venue? = nil
    @State private var selectedMapVenue: Venue? = nil
    @State private var position: MapCameraPosition = .automatic
    @State private var geocoder = CLGeocoder() // 持有长生命周期以防止异步回调时被释放导致崩溃
    
    // 自定义抽屉状态
    @State private var isPanelExpanded = false
    @State private var dragOffset: CGFloat = 0 // 使用 @State 从而能在松手动画中与 isPanelExpanded 同步归零，防止抽搐
    
    private let columns = [
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1)
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // 1. 底层铺满的地图
                Map(position: $position, selection: $selectedMapVenue) {
                    UserAnnotation()
                    
                    ForEach(viewModel.filteredVenues) { venue in
                        if let lat = venue.lat, let lng = venue.lng {
                            Annotation(venue.officialName ?? venue.name, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng)) {
                                ZStack {
                                    Circle()
                                        .fill(Theme.brandPrimary)
                                        .frame(width: 30, height: 30)
                                        .shadow(color: Theme.brandPrimary.opacity(0.4), radius: 3, x: 0, y: 1.5)
                                    
                                    Image(systemName: "dumbbell.fill")
                                        .foregroundColor(.white)
                                        .font(.system(size: 13, weight: .bold))
                                }
                            }
                            .tag(venue)
                        }
                    }
                }
                .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
                .ignoresSafeArea()
                
                // 2. 顶部状态栏渐变阴影，确保时间/电量图标清晰
                VStack {
                    LinearGradient(gradient: Gradient(colors: [Color.black.opacity(0.7), Color.clear]), startPoint: .top, endPoint: .bottom)
                        .frame(height: 80)
                        .ignoresSafeArea(edges: .top)
                    Spacer()
                }
                .allowsHitTesting(false)
                
                // 3. 自定义列表抽屉 (作为 TabBar 的外圈，底部悬浮于屏幕底边之上 12pt，与左右两边对齐)
                VStack {
                    Spacer()
                    customDrawer(geometry: geometry)
                        .padding(.bottom, 12)
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom) // 避免键盘弹出时压缩 GeometryReader 的安全高度，从而彻底解决由于抽屉尺寸重算与地图重排引起的点击卡顿
        .preferredColorScheme(.dark)
        .toolbarBackground(.hidden, for: .tabBar) // 隐藏系统原生 TabBar 的毛玻璃背景，使其融入抽屉外圈
        .onAppear {
            viewModel.initialize()
        }
        // 监听地图上大头针 of 点击
        .onChange(of: selectedMapVenue) { oldValue, newValue in
            if let venue = newValue {
                selectedVenue = venue
                selectedMapVenue = nil // 清空选中状态以便下次能再次点击
            }
        }
        // 列表数据变化时，重设地图相机视角以包含所有标记
        .onChange(of: viewModel.filteredVenues) { oldValue, newValue in
            updateCameraPosition(for: newValue)
        }
        // 监听城市选择改变，如果该城市没有场馆，则地理编码并移动到该城市中心
        .onChange(of: viewModel.selectedRegion) { oldValue, newValue in
            handleRegionChange(to: newValue)
        }
        // 场馆详情弹出页绑定在主体视图上
        .sheet(item: $selectedVenue) { venue in
            VenueDetailSheet(venue: venue)
                .presentationDetents([.fraction(0.5), .large])
                .presentationDragIndicator(.visible)
        }
    }
    
    /// 根据过滤后的场馆列表智能更新地图相机视角
    private func updateCameraPosition(for venues: [Venue]) {
        let venuesWithCoordinates = venues.filter { $0.lat != nil && $0.lng != nil }
        if !venuesWithCoordinates.isEmpty {
            withAnimation(.easeOut(duration: 0.8)) {
                position = .automatic
            }
        }
    }
    
    /// 当选中的区域（省份/城市）改变时，如果该区域没有场馆，则尝试通过地理编码移动地图
    private func handleRegionChange(to region: String) {
        if region == "全部" {
            withAnimation(.easeOut(duration: 0.8)) {
                position = .automatic
            }
            return
        }
        
        let venuesWithCoordinates = viewModel.filteredVenues.filter { $0.lat != nil && $0.lng != nil }
        // 如果该区域有场馆，会由 onChange(of: filteredVenues) 触发 updateCameraPosition 自动缩放
        guard venuesWithCoordinates.isEmpty else { return }
        
        // 否则，对城市名称进行地理编码并移到城市中心
        geocoder.geocodeAddressString(region) { placemarks, error in
            if let error = error {
                print("地理编码失败: \(error.localizedDescription)")
                return
            }
            
            if let coordinate = placemarks?.first?.location?.coordinate {
                DispatchQueue.main.async {
                    withAnimation(.easeOut(duration: 0.8)) {
                        position = .region(
                            MKCoordinateRegion(
                                center: coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
                            )
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - 自定义半屏列表抽屉内容
    
    private var drawerHeaderView: some View {
        VStack(spacing: 8) {
            // A. 顶部把手
            Capsule()
                .fill(Color.white.opacity(0.24))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
            
            // B. 地区选择与搜索条横排 (更加紧凑，取消探索场馆大标题)
            HStack(spacing: 8) {
                // 左侧地区选择器
                Menu {
                    RegionMenuView(viewModel: viewModel)
                } label: {
                    HStack(spacing: 4) {
                        Text(viewModel.selectedRegion == "全部" ? "全部城市" : viewModel.selectedRegion)
                            .font(.system(size: 13, weight: .semibold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundColor(Theme.textStrong)
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .glassEffect(.regular.interactive(), in: .capsule) // iOS 26 交互式液态玻璃质感
                }
                
                // 右侧搜索条
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Theme.textSecondary)
                        .font(.system(size: 13, weight: .bold))
                    
                    TextField("搜索场馆、器械、品牌...", text: $viewModel.searchQuery)
                        .textFieldStyle(.plain)
                        .foregroundColor(.white)
                        .font(.system(size: 13))
                        .autocorrectionDisabled()
                    
                    if !viewModel.searchQuery.isEmpty {
                        Button(action: { viewModel.searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: 36)
                .glassEffect(.regular.interactive(), in: .capsule) // iOS 26 交互式液态玻璃质感
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
    }
    
    private func customDrawer(geometry: GeometryProxy) -> some View {
        let headerHeight: CGFloat = 72
        // safeAreaInsets.bottom 在 TabView 内已包含 TabBar 高度 + Home Indicator
        let tabBarTotalHeight = geometry.safeAreaInsets.bottom
        
        // 计算屏幕物理总高度（可用区域 + 顶部安全区 + 底部安全区）
        let screenHeight = geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom
        // 展开时，由于抽屉底部有 12pt 的浮动边距，整个抽屉的高度应为屏幕高度一半减去 12pt，以保证顶部边缘依然精确对齐于屏幕中线
        let targetTotalHeight = screenHeight * 0.5 - 12
        let maxContentHeight = targetTotalHeight - headerHeight - tabBarTotalHeight
        
        let baseOffset: CGFloat = isPanelExpanded ? 0 : maxContentHeight
        let rawOffset = baseOffset + dragOffset
        // 限制拖拽偏移：向上最多拉出 24 点弹性空间，向下最多超出 40 点弹性空间
        let currentOffset = max(-24, min(maxContentHeight + 40, rawOffset))
        
        // 当 currentOffset 变化时，计算可见高度用于淡入淡出（在展开/折叠最后 60 点内平滑过渡）
        let visibleContentHeight = maxContentHeight - currentOffset
        let contentOpacity = max(0.0, min(1.0, Double(visibleContentHeight / 60.0)))
        
        let totalHeight = headerHeight + maxContentHeight + tabBarTotalHeight
        let visibleHeight = headerHeight + (maxContentHeight - currentOffset) + tabBarTotalHeight
        
        return VStack(spacing: 0) {
            // A. 头部 (始终可见)
            drawerHeaderView
                .frame(height: headerHeight)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(coordinateSpace: .global)
                        .onChanged { value in
                            // 实时同步手势位移
                            dragOffset = value.translation.height
                        }
                        .onEnded { value in
                            let velocity = value.predictedEndLocation.y - value.location.y
                            let translation = value.translation.height
                            
                            // 决定最终 snapping 目标
                            let targetExpanded: Bool
                            if translation < -50 || velocity < -100 {
                                targetExpanded = true
                            } else if translation > 50 || velocity > 100 {
                                targetExpanded = false
                            } else {
                                targetExpanded = isPanelExpanded
                            }
                            
                            // 在同一次动画事务中更新状态并清空拖拽位移，以实现完美跟手到回弹的无缝衔接
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                                isPanelExpanded = targetExpanded
                                dragOffset = 0
                            }
                        }
                )
                .offset(y: currentOffset) // 头部跟随手势进行位移
            
            // B. 内容区域 (静态外层容器 + 内部位移 + 静态裁剪，完美解决任何状态下的穿透)
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    filterBar
                        .padding(.vertical, 8)
                    
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    if viewModel.isLoading {
                        ProgressView("正在加载场馆数据...")
                            .progressViewStyle(CircularProgressViewStyle(tint: Theme.brandPrimary))
                            .foregroundColor(Theme.textPrimary)
                            .frame(maxHeight: .infinity)
                    } else if viewModel.filteredVenues.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 32))
                                .foregroundColor(Theme.textDim)
                            Text("没有找到符合条件的场馆")
                                .foregroundColor(Theme.textSecondary)
                                .font(.subheadline)
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 1) {
                                ForEach(viewModel.filteredVenues) { venue in
                                    VenueRowView(venue: venue, distanceText: viewModel.distanceString(for: venue))
                                        .onTapGesture {
                                            selectedVenue = venue
                                        }
                                }
                            }
                            .padding(.top, 8)
                            .padding(.bottom, 20)
                        }
                        .background(Color.clear)
                    }
                }
                .frame(height: maxContentHeight, alignment: .top)
                .offset(y: currentOffset) // 内部布局跟随拖动向下位移
            }
            .frame(height: maxContentHeight, alignment: .top) // 外层静态高度容器
            .clipped() // 在静态高度边界上裁剪，内容只要移出该区域即刻隐藏，绝不穿透至 TabBar
            .opacity(contentOpacity)
            .allowsHitTesting(isPanelExpanded)
            
            // C. TabBar 区域占位 (始终可见，且不随手势位移)
            Color.clear.frame(height: tabBarTotalHeight)
        }
        .frame(width: geometry.size.width - 24)
        .frame(height: totalHeight) // 固定整个容器物理高度，避免影响 Spacer 和父容器的排版
        .background(
            Color.clear
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 36))
                .overlay(
                    RoundedRectangle(cornerRadius: 36)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .frame(height: visibleHeight)
            , alignment: .bottom // 玻璃背景以底部对齐，使其在折叠时也完美保持底部 12pt 的浮起圆角，不会截断或穿过底部
        )
    }
    
    /// 排序控制栏
    private var filterBar: some View {
        HStack {
            Text("按类型与距离条件排序：")
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
            
            Spacer()
            
            // 排序选择器
            Picker("排序", selection: $viewModel.sortOption) {
                Text("距离").tag(SortOption.defaultOrder)
                Text("器械").tag(SortOption.equipment)
            }
            .pickerStyle(.segmented)
            .frame(width: 120)
        }
        .padding(.horizontal, 16)
    }
}

/// 裁判红白黄灯指示器
struct RefereeLightsView: View {
    let lights: [LightColor]
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<lights.count, id: \.self) { index in
                let light = lights[index]
                Circle()
                    .fill(color(for: light))
                    .frame(width: 6, height: 6)
                    .overlay(
                        Circle()
                            .stroke(borderColor(for: light), lineWidth: 1)
                    )
                    .shadow(color: glowColor(for: light), radius: light != .empty ? 2 : 0)
            }
        }
    }
    
    private func color(for light: LightColor) -> Color {
        switch light {
        case .white: return .white
        case .yellow: return Color(hex: "#FFD700") // 金黄色
        case .red: return Color(hex: "#FF4D4F")   // 柔和红
        case .empty: return .clear
        }
    }
    
    private func borderColor(for light: LightColor) -> Color {
        switch light {
        case .empty: return Color.white.opacity(0.3)
        default: return .clear
        }
    }
    
    private func glowColor(for light: LightColor) -> Color {
        switch light {
        case .white: return Color.white.opacity(0.4)
        case .yellow: return Color(hex: "#FFD700").opacity(0.3)
        case .red: return Color(hex: "#FF4D4F").opacity(0.3)
        case .empty: return .clear
        }
    }
}

/// 单个场馆行组件 (双列网格中的格子)
struct VenueRowView: View {
    let venue: Venue
    let distanceText: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 1. 场馆名称
            Text(venue.officialName ?? venue.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.textStrong)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // 2. 裁判灯与城市地区/备注，以及右侧距离
            HStack(alignment: .center, spacing: 0) {
                HStack(spacing: 6) {
                    RefereeLightsView(lights: venue.equipmentLights)
                    
                    Text("\(venue.displayRegion)\(venue.remark != nil && !venue.remark!.isEmpty ? " • \(venue.remark!)" : "")")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 4)
                
                if let dist = distanceText {
                    Text(dist)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Theme.brandPrimary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .frame(height: 72)
        .frame(maxWidth: .infinity)
        .background(Color.clear)
        .contentShape(Rectangle())
    }
}

/// 场馆半屏详情面板视图
struct VenueDetailSheet: View {
    let venue: Venue
    
    var body: some View {
        ZStack {
            Theme.sheetBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 顶部标题与副标题
                    VStack(alignment: .leading, spacing: 6) {
                        Text(venue.name)
                            .font(.title2)
                            .bold()
                            .foregroundColor(Theme.textStrong)
                        
                        if let official = venue.officialName {
                            Text(official)
                               .font(.subheadline)
                               .foregroundColor(Theme.textSecondary)
                        }
                        
                        // 裁判灯状态列
                        HStack(spacing: 8) {
                            RefereeLightsView(lights: venue.equipmentLights)
                            Text(venue.displayRegion)
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                        .padding(.top, 4)
                    }
                    
                    Divider()
                        .background(Theme.borderStrong)
                    
                    // 位置信息
                    VStack(alignment: .leading, spacing: 10) {
                        Label {
                            Text(venue.address ?? venue.location)
                                .font(.body)
                                .foregroundColor(Theme.textPrimary)
                        } icon: {
                            Image(systemName: "map")
                                .foregroundColor(Theme.brandPrimary)
                        }
                        
                        if let remark = venue.remark {
                            Label {
                                Text(remark)
                                    .font(.body)
                                    .foregroundColor(Theme.textSecondary)
                            } icon: {
                                Image(systemName: "info.circle")
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                    }
                    
                    Divider()
                        .background(Theme.borderStrong)
                    
                    // 器械明细
                    Text("器械设备规格")
                        .font(.headline)
                        .foregroundColor(Theme.textStrong)
                    
                    if venue.hasEquipment {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(venue.equipmentDisplaySlots) { slot in
                                detailRow(title: slot.label, value: slot.value, brand: slot.brandLine.isEmpty ? nil : slot.brandLine)
                                if slot.key != "barbellBrand" {
                                    Divider()
                                        .background(Theme.border)
                                }
                            }
                            
                            if let note = venue.equipment?.note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("器械备注")
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                    Text(note)
                                        .font(.footnote)
                                        .foregroundColor(Theme.textPrimary)
                                        .lineSpacing(4)
                                }
                                .padding(.top, 8)
                            }
                        }
                        .padding()
                        .background(Theme.panelBackground)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Theme.borderStrong, lineWidth: 1)
                        )
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "circle.slash")
                                .font(.title)
                                .foregroundColor(Theme.textDim)
                            Text("暂无详细器械登记数据")
                                .foregroundColor(Theme.textSecondary)
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                    }
                }
                .padding()
            }
        }
    }
    
    private func detailRow(title: String, value: String, brand: String?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(value)
                    .font(.system(size: 14))
                    .bold()
                    .foregroundColor(Theme.textStrong)
                
                if let b = brand {
                    Text(b)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Theme.brandPrimary)
                }
            }
        }
    }
}

// MARK: - SwiftUI 预览区域

#Preview("全屏地图列表") {
    VenuesView()
}

#Preview("场馆半屏详情") {
    VenueDetailSheet(venue: Venue(
        id: "test-preview-id",
        name: "铁馆测试",
        city: "北京",
        province: "北京",
        location: "116.397128,39.916527",
        officialName: "北京硬派铁馆 (力量举专业馆)",
        address: "朝阳区北苑路东甲 10 号",
        district: "朝阳区",
        remark: "备有多台比赛级 Combo Rack 与原装杠铃",
        lat: 39.916527,
        lng: 116.397128,
        equipment: VenueEquipment(
            rackCount: 3,
            platformCount: 2,
            steelPlateCount: 5,
            rackCountText: "3台",
            platformCountText: "2个",
            steelPlateCountText: "5套及以上",
            steelPlateWeightText: "1000kg+",
            rackBrand: "Eleiko",
            plateBrand: "DHS",
            barbellBrand: "Zhangkong",
            note: "杠铃/钢片品牌：Eleiko"
        )
    ))
}

/// 蓝图网格背景图，对齐小程序 empty-state
struct GridPattern: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step: CGFloat = 28
        
        // 垂直线
        var x: CGFloat = 0
        while x < rect.width {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
            x += step
        }
        
        // 水平线
        var y: CGFloat = 0
        while y < rect.height {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
            y += step
        }
        
        return path
    }
}

/// 地区选择菜单子视图 - 提取为独立 View 以实现惰性计算，避免拖拽抽屉时频繁在主视图中计算与 Diff
struct RegionMenuView: View {
    @ObservedObject var viewModel: VenuesViewModel
    
    var body: some View {
        Button("全部城市") {
            viewModel.selectedRegion = "全部"
        }
        
        ForEach(viewModel.sortedProvinces, id: \.self) { province in
            Menu(province) {
                Button("全部\(province)") {
                    viewModel.selectedRegion = province
                }
                ForEach(viewModel.provinceMap[province] ?? [], id: \.self) { city in
                    Button(city) {
                        viewModel.selectedRegion = city
                    }
                }
            }
        }
    }
}
