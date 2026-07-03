import Foundation
import CoreLocation
import Combine

/// 场馆页状态管理器 (ViewModel)
class VenuesViewModel: ObservableObject {
    
    // MARK: - Published 属性 (UI 绑定)
    
    /// 原始场馆列表
    @Published var allVenues: [Venue] = []
    
    /// 过滤排序后展示的场馆列表
    @Published var filteredVenues: [Venue] = []
    
    /// 可供选择的省份与城市地图 (Key: 省份, Value: 城市列表)
    @Published var provinceMap: [String: [String]] = [:]
    
    /// 排序后的省份列表，避免在 View body 中频繁排序计算导致卡顿
    @Published var sortedProvinces: [String] = []
    
    /// 筛选条件：选择的城市或省份
    @Published var selectedRegion: String = "全部" {
        didSet { applyFilters() }
    }
    
    /// 筛选条件：搜索关键字
    @Published var searchQuery: String = "" {
        didSet { applyFilters() }
    }
    
    /// 筛选条件：多选器械关键字集合
    @Published var selectedEquipments: Set<String> = [] {
        didSet { applyFilters() }
    }
    
    /// 筛选条件：排序规则
    @Published var sortOption: SortOption = .defaultOrder {
        didSet { applyFilters() }
    }
    
    /// 加载状态
    @Published var isLoading = false
    
    /// 错误信息
    @Published var errorMessage: String?
    
    /// 定位失败错误
    @Published var locationError: Error?
    
    // MARK: - 内部依赖
    
    private let locationManager = LocationManager()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupLocationBindings()
    }
    
    /// 开始初始化加载数据与请求定位
    func initialize() {
        loadLocalFallbackData()
        locationManager.requestLocationPermission()
    }
    
    /// 重试定位更新
    func retryLocation() {
        self.locationError = nil
        locationManager.requestLocationPermission()
    }
    
    /// 绑定定位更新事件
    private func setupLocationBindings() {
        // 当经纬度更新时，自动重算距离并重新过滤排序
        locationManager.$userLocation
            .receive(on: RunLoop.main)
            .sink { [weak self] location in
                guard let self = self else { return }
                self.applyFilters()
            }
            .store(in: &cancellables)
            
        // 自动将定位到的城市设置为当前选择地区 (如果是“全部”的话)
        locationManager.$currentCity
            .receive(on: RunLoop.main)
            .compactMap { $0 }
            .sink { [weak self] city in
                guard let self = self else { return }
                print("📍 [VenuesViewModel] 监听到定位城市更新: \(city)")
                if self.selectedRegion == "全部" {
                    print("📍 [VenuesViewModel] 自动将当前选择地区从 '全部' 设为定位城市: \(city)")
                    self.selectedRegion = city
                } else {
                    print("📍 [VenuesViewModel] 当前选择地区已是: \(self.selectedRegion)，忽略自动定位切换")
                }
            }
            .store(in: &cancellables)
            
        // 监听定位错误更新
        locationManager.$lastError
            .receive(on: RunLoop.main)
            .sink { [weak self] error in
                guard let self = self else { return }
                self.locationError = error
            }
            .store(in: &cancellables)
    }
    
    /// 从本地 Fallback JSON 加载场馆数据
    func loadLocalFallbackData() {
        self.isLoading = true
        self.errorMessage = nil
        
        // 在实际 Xcode 中，可以通过 Bundle.main 加载 JSON 文件
        // 这里提供加载的标准框架
        guard let url = Bundle.main.url(forResource: "venues_data", withExtension: "json") else {
            self.errorMessage = "未找到 venues_data.json 文件"
            self.isLoading = false
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let data = try Data(contentsOf: url)
                let decodedVenues = try JSONDecoder().decode([Venue].self, from: data)
                
                // 构建省市字典地图供筛选下拉框使用
                let map = Self.buildProvinceMap(decodedVenues)
                
                DispatchQueue.main.async {
                    self.allVenues = decodedVenues
                    self.provinceMap = map
                    self.sortedProvinces = Array(map.keys).sorted(by: <) // 缓存排序后的省份列表，避免在 UI 线程的 View body 中反复排序计算
                    self.applyFilters()
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "解析本地数据失败: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    /// 执行筛选与排序
    func applyFilters() {
        self.filteredVenues = VenueFilterService.filterAndSort(
            allVenues,
            region: selectedRegion,
            searchQuery: searchQuery,
            selectedEquipments: selectedEquipments,
            sortOption: sortOption,
            userLocation: locationManager.userLocation
        )
    }
    
    /// 辅助方法：计算单个场馆到用户当前位置的距离文本表示
    func distanceString(for venue: Venue) -> String? {
        guard let dist = VenueFilterService.calculateDistance(from: locationManager.userLocation, to: venue) else {
            return nil
        }
        if dist < 1000 {
            return String(format: "%.0f 米", dist)
        } else {
            return String(format: "%.1f 公里", dist / 1000.0)
        }
    }
    
    // MARK: - 省市归类地图逻辑 (从 filters.js 中的 buildProvinceMap 移植)
    
    private static func buildProvinceMap(_ venues: [Venue]) -> [String: [String]] {
        var map: [String: Set<String>] = [:]
        for v in venues {
            guard !v.province.isEmpty, !v.city.isEmpty else { continue }
            map[v.province, default: Set<String>()].insert(v.city)
        }
        
        // 转换成按拼音/首字母或排序权重排序的字典数组
        var sortedMap: [String: [String]] = [:]
        for (prov, cities) in map {
            sortedMap[prov] = Array(cities).sorted(by: <)
        }
        return sortedMap
    }
}
