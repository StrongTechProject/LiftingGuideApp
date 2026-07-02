import SwiftUI

struct Theme {
    static let background = Color(hex: "#000000")
    static let elevatedBackground = Color(hex: "#050505")
    static let panelBackground = Color(hex: "#111111")
    static let sheetBackground = Color(hex: "#121212")
    static let mutedBackground = Color(hex: "#161616")
    static let brandPrimary = Color(hex: "#E62B1E") // 品牌红 (微信小程序对应)
    
    static let textPrimary = Color(hex: "#D1D4DC")
    static let textStrong = Color.white
    static let textSecondary = Color(hex: "#888888")
    static let textDim = Color(hex: "#555555")
    
    static let border = Color(hex: "#161616")
    static let borderStrong = Color(hex: "#222222")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
