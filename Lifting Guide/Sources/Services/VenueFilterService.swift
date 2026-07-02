import Foundation
import CoreLocation

/// 场馆排序选项
enum SortOption {
    case defaultOrder // 按距离排序
    case equipment    // 按器械完善度排序
}

/// 场馆筛选与排序核心服务 (从 filters.js 移植)
struct VenueFilterService {
    
    /// 根据条件筛选并排序场馆
    static func filterAndSort(
        _ venues: [Venue],
        region: String,
        searchQuery: String,
        selectedEquipments: Set<String>,
        sortOption: SortOption,
        userLocation: CLLocation?
    ) -> [Venue] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // 1. 过滤
        let filtered = venues.filter { venue in
            // A. 地区过滤
            let matchesRegion = (region == "全部" || venue.city == region || venue.province == region)
            guard matchesRegion else { return false }
            
            // B. 器械多选过滤 (如果有选中的器械条件)
            if !selectedEquipments.isEmpty {
                // 检查场馆拥有的器械是否包含所有选中的器械
                // 这里简化匹配：如果选中的是特定的器械牌子或特征，可以自定义逻辑。
                // 暂时支持：如果场馆器械信息不为空，且匹配选中的器械关键字
                guard let eq = venue.equipment else { return false }
                for reqEq in selectedEquipments {
                    let hasReq = checkVenueHasEquipment(eq, keyword: reqEq)
                    if !hasReq { return false }
                }
            }
            
            // C. 关键字搜索过滤 (匹配场馆及器械字段)
            if !query.isEmpty {
                let matchesSearch = checkVenueMatchesQuery(venue, query: query)
                guard matchesSearch else { return false }
            }
            
            return true
        }
        
        // 2. 排序
        switch sortOption {
        case .defaultOrder:
            return sortByDistance(filtered, userLocation: userLocation)
        case .equipment:
            return sortByEquipment(filtered, userLocation: userLocation)
        }
    }
    
    // MARK: - 辅助计算方法
    
    /// 计算用户到场馆的距离（单位：米）
    static func calculateDistance(from userLocation: CLLocation?, to venue: Venue) -> Double? {
        guard let userLoc = userLocation,
              let lat = venue.lat,
              let lng = venue.lng else {
            return nil
        }
        let venueLoc = CLLocation(latitude: lat, longitude: lng)
        return userLoc.distance(from: venueLoc) // Apple 原生大圆距离计算 (WGS84)
    }
    
    /// 按距离排序
    private static func sortByDistance(_ venues: [Venue], userLocation: CLLocation?) -> [Venue] {
        guard let userLoc = userLocation else {
            // 没有定位时，保持原顺序
            return venues
        }
        
        return venues.sorted { (v1, v2) -> Bool in
            let d1 = calculateDistance(from: userLoc, to: v1) ?? Double.infinity
            let d2 = calculateDistance(from: userLoc, to: v2) ?? Double.infinity
            return d1 < d2
        }
    }
    
    /// 按器械完善度排序
    private static func sortByEquipment(_ venues: [Venue], userLocation: CLLocation?) -> [Venue] {
        return venues.sorted { (v1, v2) -> Bool in
            // A. 是否有真实数据优先
            let hasEq1 = v1.equipment != nil
            let hasEq2 = v2.equipment != nil
            if hasEq1 != hasEq2 {
                return hasEq1 && !hasEq2
            }
            
            // B. 白灯数量（如有评分，这里简化为 rackCount 赛架数量作为主要指标）
            let score1 = v1.equipment?.rackCount ?? 0
            let score2 = v2.equipment?.rackCount ?? 0
            if score1 != score2 {
                return score1 > score2
            }
            
            // C. 距离作为第三优先级
            if let userLoc = userLocation {
                let d1 = calculateDistance(from: userLoc, to: v1) ?? Double.infinity
                let d2 = calculateDistance(from: userLoc, to: v2) ?? Double.infinity
                return d1 < d2
            }
            
            return v1.name < v2.name
        }
    }
    
    /// 检查场馆是否匹配搜索词
    private static func checkVenueMatchesQuery(_ venue: Venue, query: String) -> Bool {
        if venue.name.lowercased().contains(query) ||
            venue.city.lowercased().contains(query) ||
            venue.province.lowercased().contains(query) ||
            venue.location.lowercased().contains(query) ||
            (venue.officialName?.lowercased().contains(query) ?? false) ||
            (venue.address?.lowercased().contains(query) ?? false) ||
            (venue.district?.lowercased().contains(query) ?? false) ||
            (venue.remark?.lowercased().contains(query) ?? false) {
            return true
        }
        
        if let eq = venue.equipment {
            if (eq.rackCountText?.lowercased().contains(query) ?? false) ||
                (eq.platformCountText?.lowercased().contains(query) ?? false) ||
                (eq.steelPlateCountText?.lowercased().contains(query) ?? false) ||
                (eq.steelPlateWeightText?.lowercased().contains(query) ?? false) ||
                (eq.rackBrand?.lowercased().contains(query) ?? false) ||
                (eq.plateBrand?.lowercased().contains(query) ?? false) ||
                (eq.barbellBrand?.lowercased().contains(query) ?? false) ||
                (eq.note?.lowercased().contains(query) ?? false) {
                return true
            }
        }
        
        return false
    }
    
    /// 检查是否包含指定的器械特征
    private static func checkVenueHasEquipment(_ eq: VenueEquipment, keyword: String) -> Bool {
        let kw = keyword.lowercased()
        
        // 匹配各种品牌或备注中提到的词
        if (eq.rackBrand?.lowercased().contains(kw) ?? false) ||
            (eq.plateBrand?.lowercased().contains(kw) ?? false) ||
            (eq.barbellBrand?.lowercased().contains(kw) ?? false) ||
            (eq.note?.lowercased().contains(kw) ?? false) {
            return true
        }
        
        // 匹配一些通用品类词
        if kw == "赛架" || kw == "combo rack" {
            return (eq.rackCount ?? 0) > 0 || (eq.rackCountText != nil)
        }
        if kw == "硬拉台" || kw == "platform" {
            return (eq.platformCount ?? 0) > 0 || (eq.platformCountText != nil)
        }
        if kw == "铁片" || kw == "steel plates" {
            return (eq.steelPlateCount ?? 0) > 0 || (eq.steelPlateCountText != nil)
        }
        
        return false
    }
}
