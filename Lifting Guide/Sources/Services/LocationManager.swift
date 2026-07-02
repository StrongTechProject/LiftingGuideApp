import Foundation
import CoreLocation
import Combine

/// 基于 CoreLocation 的 iOS 原生定位服务管理器
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    
    // 发布当前经纬度和解析出的城市地区
    @Published var userLocation: CLLocation?
    @Published var currentCity: String?
    @Published var currentProvince: String?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLocating = false
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        self.authorizationStatus = manager.authorizationStatus
    }
    
    deinit {
        print("📍 [LocationManager] 析构被调用，清理定位资源...")
        manager.delegate = nil
        manager.stopUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.stopUpdatingHeading()
        }
    }
    
    /// 请求定位权限
    func requestLocationPermission() {
        let status = manager.authorizationStatus
        print("📍 [LocationManager] 请求定位权限，当前状态: \(status.rawValue)")
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            print("📍 [LocationManager] 已获得定位授权，直接开始更新位置")
            startUpdatingLocation()
        } else {
            print("📍 [LocationManager] 未授权，向系统请求 WhenInUse 授权")
            manager.requestWhenInUseAuthorization()
        }
    }
    
    /// 开始单次定位
    func startUpdatingLocation() {
        print("📍 [LocationManager] 开始单次定位更新...")
        isLocating = true
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            print("📍 [LocationManager] 设备支持朝向，开始更新朝向")
            manager.startUpdatingHeading()
        }
    }
    
    /// 停止定位以节省电力
    func stopUpdatingLocation() {
        print("📍 [LocationManager] 停止定位更新")
        manager.stopUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            print("📍 [LocationManager] 设备支持朝向，停止更新朝向")
            manager.stopUpdatingHeading()
        }
        isLocating = false
    }
    
    // MARK: - CLLocationManagerDelegate 实现
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
            print("📍 [LocationManager] 授权状态变更: \(manager.authorizationStatus.rawValue)")
            if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
                self.startUpdatingLocation()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        
        print("📍 [LocationManager] 收到 GPS 坐标: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        
        DispatchQueue.main.async {
            self.userLocation = location
            self.stopUpdatingLocation() // 单次定位获取后即停止，防止耗电
            
            // 执行原生逆地址解析 (Reverse Geocoding)，免去小程序云开发依赖
            print("📍 [LocationManager] 开始逆地理编码...")
            self.geocoder.reverseGeocodeLocation(location) { placemarks, error in
                if let error = error {
                    print("📍 [LocationManager] 逆地理编码失败: \(error.localizedDescription)")
                    return
                }
                
                if let placemark = placemarks?.first {
                    // 提取省份和城市并进行本地归一化匹配（去掉“省”、“市”等后缀）
                    let rawProvince = placemark.administrativeArea ?? ""
                    let rawCity = placemark.locality ?? placemark.subAdministrativeArea ?? ""
                    
                    let normProvince = self.normalizeRegion(rawProvince)
                    let normCity = self.normalizeRegion(rawCity)
                    
                    print("📍 [LocationManager] 逆地理编码成功 -> 原始省: \(rawProvince), 原始市: \(rawCity) | 归一化省: \(normProvince), 归一化市: \(normCity)")
                    
                    self.currentProvince = normProvince
                    self.currentCity = normCity
                } else {
                    print("📍 [LocationManager] 逆地理编码未返回有效 placemarks")
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("📍 [LocationManager] 定位请求失败: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.isLocating = false
        }
    }
    
    // MARK: - 辅助清洗逻辑 (对应小程序 normalizeRegion)
    
    /// 归一化地区名称 (去除行政区后缀以匹配本地 JSON 配置)
    private func normalizeRegion(_ name: String) -> String {
        guard !name.isEmpty else { return "" }
        let pattern = "(特别行政区|壮族自治区|回族自治区|维吾尔自治区|自治区|省|市|盟|地区|新区|区|县)$"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let range = NSRange(location: 0, length: name.utf16.count)
            let modified = regex.stringByReplacingMatches(in: name, options: [], range: range, withTemplate: "")
            return modified
        }
        return name
    }
}
