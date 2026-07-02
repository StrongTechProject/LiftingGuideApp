import Foundation

/// 场馆内的器械配置数据模型
struct VenueEquipment: Codable, Hashable {
    var rackCount: Int?
    var platformCount: Int?
    var steelPlateCount: Int?
    var rackCountText: String?
    var platformCountText: String?
    var steelPlateCountText: String?
    var steelPlateWeightText: String?
    var rackBrand: String?
    var plateBrand: String?
    var barbellBrand: String?
    var note: String?
}

/// 场馆核心数据模型
struct Venue: Identifiable, Codable, Hashable {
    // 基础必填字段
    let id: String
    let name: String
    let city: String
    let province: String
    let location: String // 经纬度文本表示，如 "116.397128,39.916527"
    
    // 可选详细字段
    var officialName: String?
    var address: String?
    var district: String?
    var remark: String?
    var lat: Double?
    var lng: Double?
    var equipment: VenueEquipment?
    
    // 字段名转换以匹配原始小程序的 JSON
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case city
        case province
        case location
        case officialName = "official_name"
        case address
        case district
        case remark
        case lat
        case lng
        case equipment
    }
    
    // 显式定义成员初始化器，供 Preview 或测试数据构建使用
    init(
        id: String,
        name: String,
        city: String,
        province: String,
        location: String,
        officialName: String? = nil,
        address: String? = nil,
        district: String? = nil,
        remark: String? = nil,
        lat: Double? = nil,
        lng: Double? = nil,
        equipment: VenueEquipment? = nil
    ) {
        self.id = id
        self.name = name
        self.city = city
        self.province = province
        self.location = location
        self.officialName = officialName
        self.address = address
        self.district = district
        self.remark = remark
        self.lat = lat
        self.lng = lng
        self.equipment = equipment
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 兼容处理 JSON 中 id 为 Int 或 String 的情况
        if let intId = try? container.decode(Int.self, forKey: .id) {
            self.id = String(intId)
        } else {
            self.id = try container.decode(String.self, forKey: .id)
        }
        
        self.name = try container.decode(String.self, forKey: .name)
        self.city = try container.decode(String.self, forKey: .city)
        self.province = try container.decode(String.self, forKey: .province)
        self.location = try container.decode(String.self, forKey: .location)
        self.officialName = try container.decodeIfPresent(String.self, forKey: .officialName)
        self.address = try container.decodeIfPresent(String.self, forKey: .address)
        self.district = try container.decodeIfPresent(String.self, forKey: .district)
        self.remark = try container.decodeIfPresent(String.self, forKey: .remark)
        self.lat = try container.decodeIfPresent(Double.self, forKey: .lat)
        self.lng = try container.decodeIfPresent(Double.self, forKey: .lng)
        self.equipment = try container.decodeIfPresent(VenueEquipment.self, forKey: .equipment)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(city, forKey: .city)
        try container.encode(province, forKey: .province)
        try container.encode(location, forKey: .location)
        try container.encodeIfPresent(officialName, forKey: .officialName)
        try container.encodeIfPresent(address, forKey: .address)
        try container.encodeIfPresent(district, forKey: .district)
        try container.encodeIfPresent(remark, forKey: .remark)
        try container.encodeIfPresent(lat, forKey: .lat)
        try container.encodeIfPresent(lng, forKey: .lng)
        try container.encodeIfPresent(equipment, forKey: .equipment)
    }
}

// MARK: - 裁判灯与器械展示辅助模型

enum LightColor: String, Codable {
    case empty
    case red
    case yellow
    case white
}

struct EquipmentDisplaySlot: Identifiable, Hashable {
    var id: String { key }
    let key: String
    let label: String
    let value: String
    let unit: String
    let brandLine: String
}

// MARK: - Venue 业务属性扩展

extension Venue {
    var equipmentLights: [LightColor] {
        return equipment?.buildEquipmentLights() ?? [.empty, .empty, .empty]
    }
    
    var hasEquipment: Bool {
        return equipment != nil
    }
    
    var hasRealData: Bool {
        guard let eq = equipment else { return false }
        return eq.rackCount != nil || eq.rackCountText != nil ||
               eq.steelPlateCount != nil || eq.steelPlateCountText != nil ||
               eq.steelPlateWeightText != nil ||
               eq.platformCount != nil || eq.platformCountText != nil
    }
    
    var equipmentDisplaySlots: [EquipmentDisplaySlot] {
        return equipment?.buildEquipmentDisplaySlots() ?? []
    }
    
    var displayRegion: String {
        var parts: [String] = []
        if !province.isEmpty { parts.append(province) }
        if !city.isEmpty && city != province { parts.append(city) }
        if let dist = district, !dist.isEmpty { parts.append(dist) }
        return parts.joined(separator: " ")
    }
}

// MARK: - VenueEquipment 业务规则扩展

extension VenueEquipment {
    
    func buildEquipmentLights() -> [LightColor] {
        var lights: [LightColor] = [.empty, .empty, .empty]
        
        let rackCountVal = rackCount ?? 0
        let rackSignal = parseThresholdSignal(rackCountText, units: ["台赛架", "个赛架", "台", "个", "组"])
        if hasExplicitStatData(rackCount, rackCountText) {
            lights[0] = .red
            if rackCountVal >= 2 || (rackSignal != nil && (rackSignal!.value >= 2 || rackSignal!.hasPlus)) {
                lights[0] = .white
            } else if rackCountVal == 1 || (rackSignal != nil && rackSignal!.value >= 1) {
                lights[0] = .yellow
            }
        }
        
        let plateCountVal = steelPlateCount ?? 0
        let plateSignal = parseThresholdSignal(steelPlateCountText, units: ["套", "对"])
        let plateWeightSignal = parseWeightSignal(steelPlateWeightText)
        if hasExplicitStatData(steelPlateCount, steelPlateCountText) || !(steelPlateWeightText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) {
            lights[1] = .red
            if plateCountVal >= 3 || (plateSignal != nil && (plateSignal!.value >= 3 || plateSignal!.hasPlus)) || plateWeightSignal != nil {
                lights[1] = .white
            } else if plateCountVal > 0 || (plateSignal != nil && plateSignal!.value > 0) {
                lights[1] = .yellow
            }
        }
        
        let platformCountVal = platformCount ?? 0
        let platformSignal = parseThresholdSignal(platformCountText, units: ["个硬拉台", "台硬拉台", "个", "台"])
        if hasExplicitStatData(platformCount, platformCountText) {
            lights[2] = .red
            if platformCountVal >= 2 || (platformSignal != nil && (platformSignal!.value >= 2 || platformSignal!.hasPlus)) {
                lights[2] = .white
            } else if platformCountVal == 1 || (platformSignal != nil && platformSignal!.value >= 1) {
                lights[2] = .yellow
            }
        }
        
        return lights
    }
    
    func buildEquipmentDisplaySlots() -> [EquipmentDisplaySlot] {
        let resolved = resolveEquipmentBrandsFromNote()
        
        var rackValue = "-"
        if rackCount != nil || rackCountText != nil {
            let rawValue = rackCount != nil ? "\(rackCount!)" : (rackCountText ?? "")
            if let count = Int(rawValue) {
                rackValue = "\(count)组"
            } else if rawValue.hasSuffix("+"), let count = Int(rawValue.dropLast()) {
                rackValue = "\(count)组及以上"
            } else {
                let rangePattern = "^(\\d+)\\s*-\\s*(\\d+)(组)?$"
                if let regex = try? NSRegularExpression(pattern: rangePattern, options: []),
                   let match = regex.firstMatch(in: rawValue, options: [], range: NSRange(location: 0, length: rawValue.utf16.count)) {
                    let r1 = Range(match.range(at: 1), in: rawValue)!
                    let r2 = Range(match.range(at: 2), in: rawValue)!
                    rackValue = "\(rawValue[r1])-\(rawValue[r2])组"
                } else {
                    rackValue = rawValue
                }
            }
        }
        
        var plateValue = "-"
        if let countValue = formatSteelPlateCountStat() {
            plateValue = countValue
        } else if let weightText = steelPlateWeightText?.trimmingCharacters(in: .whitespacesAndNewlines), !weightText.isEmpty {
            plateValue = weightText
        }
        
        var platformValue = "-"
        if platformCount != nil || platformCountText != nil {
            let rawValue = platformCount != nil ? "\(platformCount!)" : (platformCountText ?? "")
            if let count = Int(rawValue) {
                platformValue = "\(count)个"
            } else if rawValue.hasSuffix("+"), let count = Int(rawValue.dropLast()) {
                platformValue = "\(count)个及以上"
            } else {
                let rangePattern = "^(\\d+)\\s*-\\s*(\\d+)(个)?$"
                if let regex = try? NSRegularExpression(pattern: rangePattern, options: []),
                   let match = regex.firstMatch(in: rawValue, options: [], range: NSRange(location: 0, length: rawValue.utf16.count)) {
                    let r1 = Range(match.range(at: 1), in: rawValue)!
                    let r2 = Range(match.range(at: 2), in: rawValue)!
                    platformValue = "\(rawValue[r1])-\(rawValue[r2])个"
                } else {
                    platformValue = rawValue
                }
            }
        }
        
        let barbellBrandVal = !resolved.barbellBrand.isEmpty ? formatEquipmentBrand(resolved.barbellBrand) : "-"
        
        return [
            EquipmentDisplaySlot(
                key: "rackCount",
                label: "赛架",
                value: rackValue,
                unit: "",
                brandLine: formatEquipmentBrand(resolved.rackBrand)
            ),
            EquipmentDisplaySlot(
                key: "steelPlateCount",
                label: "钢片",
                value: plateValue,
                unit: "",
                brandLine: formatEquipmentBrand(resolved.plateBrand)
            ),
            EquipmentDisplaySlot(
                key: "platformCount",
                label: "硬拉台",
                value: platformValue,
                unit: "",
                brandLine: ""
            ),
            EquipmentDisplaySlot(
                key: "barbellBrand",
                label: "杠铃品牌",
                value: barbellBrandVal,
                unit: "",
                brandLine: ""
            )
        ]
    }
    
    // MARK: - 内部解析与格式化辅助方法
    
    struct ThresholdSignal {
        var value: Int
        var maxValue: Int?
        var hasPlus: Bool
        var hasBelow: Bool
        var hasRange: Bool
    }
    
    private func parseThresholdSignal(_ value: String?, units: [String]) -> ThresholdSignal? {
        guard let text = value?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }
        
        if let val = Int(text) {
            return ThresholdSignal(value: val, maxValue: nil, hasPlus: false, hasBelow: false, hasRange: false)
        }
        
        let rangePattern = "^(\\d+)\\s*-\\s*(\\d+)([^\\d]*)$"
        if let regex = try? NSRegularExpression(pattern: rangePattern, options: []),
           let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) {
            if let r1 = Range(match.range(at: 1), in: text),
               let r2 = Range(match.range(at: 2), in: text) {
                let val1 = Int(text[r1]) ?? 0
                let val2 = Int(text[r2]) ?? 0
                var unit = ""
                if match.range(at: 3).location != NSNotFound, let r3 = Range(match.range(at: 3), in: text) {
                    unit = String(text[r3])
                }
                if unit.isEmpty || units.contains(unit) {
                    return ThresholdSignal(value: val1, maxValue: val2, hasPlus: false, hasBelow: false, hasRange: true)
                }
            }
        }
        
        let plusPattern = "^(\\d+)\\+$"
        if let regex = try? NSRegularExpression(pattern: plusPattern, options: []),
           let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) {
            if let r1 = Range(match.range(at: 1), in: text) {
                let val = Int(text[r1]) ?? 0
                return ThresholdSignal(value: val, maxValue: nil, hasPlus: true, hasBelow: false, hasRange: false)
            }
        }
        
        let escapedUnits = units.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
        let thresholdPattern = "^(\\d+)(?:\(escapedUnits))(?:及以上|以上|\\+|以下)?$"
        if let regex = try? NSRegularExpression(pattern: thresholdPattern, options: []),
           let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) {
            if let r1 = Range(match.range(at: 1), in: text) {
                let val = Int(text[r1]) ?? 0
                let hasPlus = text.contains("及以上") || text.contains("以上") || text.contains("+")
                let hasBelow = text.contains("以下")
                return ThresholdSignal(value: val, maxValue: nil, hasPlus: hasPlus, hasBelow: hasBelow, hasRange: false)
            }
        }
        
        let inlinePattern = "(\\d+)(?:\(escapedUnits))(及以上|以上|\\+)"
        if let regex = try? NSRegularExpression(pattern: inlinePattern, options: []),
           let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) {
            if let r1 = Range(match.range(at: 1), in: text) {
                let val = Int(text[r1]) ?? 0
                return ThresholdSignal(value: val, maxValue: nil, hasPlus: true, hasBelow: false, hasRange: false)
            }
        }
        
        return nil
    }
    
    struct WeightSignal {
        var value: Double
        var hasPlus: Bool
    }
    
    private func parseWeightSignal(_ value: String?) -> WeightSignal? {
        guard let text = value?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }
        let pattern = "^(\\d+(?:\\.\\d+)?)kg(\\+)?$"
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) {
            if let r1 = Range(match.range(at: 1), in: text) {
                let val = Double(text[r1]) ?? 0.0
                let plus = match.range(at: 2).location != NSNotFound
                return WeightSignal(value: val, hasPlus: plus)
            }
        }
        return nil
    }
    
    private func hasExplicitStatData(_ exactValue: Int?, _ textValue: String?) -> Bool {
        if exactValue != nil { return true }
        return !(textValue?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }
    
    private func formatSteelPlateCountStat() -> String? {
        guard let text = steelPlateCountText?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            if let count = steelPlateCount {
                return "\(count)套"
            }
            return nil
        }
        
        let rawPattern = "^(\\d+)(\\+)?$"
        if let regex = try? NSRegularExpression(pattern: rawPattern, options: []),
           let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) {
            if let r1 = Range(match.range(at: 1), in: text) {
                let val = text[r1]
                let plus = match.range(at: 2).location != NSNotFound
                return "\(val)套\(plus ? "及以上" : "")"
            }
        }
        
        let normPattern = "^(\\d+)(套|对)(\\+|及以上|以上)?$"
        if let regex = try? NSRegularExpression(pattern: normPattern, options: []),
           let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) {
            if let r1 = Range(match.range(at: 1), in: text) {
                let val = text[r1]
                let plus = match.range(at: 3).location != NSNotFound
                return "\(val)套\(plus ? "及以上" : "")"
            }
        }
        
        return text
    }
    
    struct ResolvedBrands {
        var rackBrand: String
        var plateBrand: String
        var barbellBrand: String
        var note: String
    }
    
    private func resolveEquipmentBrandsFromNote() -> ResolvedBrands {
        let noteText = (note ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        var resolved = ResolvedBrands(
            rackBrand: (rackBrand ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            plateBrand: (plateBrand ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            barbellBrand: (barbellBrand ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            note: noteText
        )
        
        if noteText.isEmpty {
            return resolved
        }
        
        let segments = noteText
            .components(separatedBy: CharacterSet(charactersIn: ";；"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            
        var remaining: [String] = []
        
        for segment in segments {
            let sharedPattern = "^杠铃/钢片品牌[:：]\\s*(.+)$"
            if let regex = try? NSRegularExpression(pattern: sharedPattern, options: []),
               let match = regex.firstMatch(in: segment, options: [], range: NSRange(location: 0, length: segment.utf16.count)) {
                if let r = Range(match.range(at: 1), in: segment) {
                    let brand = String(segment[r]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if resolved.barbellBrand.isEmpty { resolved.barbellBrand = brand }
                    if resolved.plateBrand.isEmpty { resolved.plateBrand = brand }
                    continue
                }
            }
            
            let barbellPattern = "^杠铃品牌[:：]\\s*(.+)$"
            if let regex = try? NSRegularExpression(pattern: barbellPattern, options: []),
               let match = regex.firstMatch(in: segment, options: [], range: NSRange(location: 0, length: segment.utf16.count)) {
                if let r = Range(match.range(at: 1), in: segment) {
                    let brand = String(segment[r]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if resolved.barbellBrand.isEmpty { resolved.barbellBrand = brand }
                    continue
                }
            }
            
            let platePattern = "^钢片品牌[:：]\\s*(.+)$"
            if let regex = try? NSRegularExpression(pattern: platePattern, options: []),
               let match = regex.firstMatch(in: segment, options: [], range: NSRange(location: 0, length: segment.utf16.count)) {
                if let r = Range(match.range(at: 1), in: segment) {
                    let brand = String(segment[r]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if resolved.plateBrand.isEmpty { resolved.plateBrand = brand }
                    continue
                }
            }
            
            remaining.append(segment)
        }
        
        resolved.note = remaining.joined(separator: "；")
        return resolved
    }
    
    private func formatEquipmentBrand(_ value: String) -> String {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "" }
        
        let pattern = "[A-Za-z]+"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let nsText = text as NSString
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
            var result = text
            for match in matches.reversed() {
                let range = match.range
                let fragment = nsText.substring(with: range)
                let uppercased = fragment.uppercased()
                result = (result as NSString).replacingCharacters(in: range, with: uppercased)
            }
            return result
        }
        
        return text
    }
}

