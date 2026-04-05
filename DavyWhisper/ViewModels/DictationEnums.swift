import Foundation

enum IndicatorStyle: String, CaseIterable {
    case notch
    case overlay
}

enum NotchIndicatorVisibility: String, CaseIterable {
    case always
    case duringActivity
    case never
}

enum NotchIndicatorContent: String, CaseIterable {
    case indicator
    case timer
    case waveform
    case profile
    case none
}

enum NotchIndicatorDisplay: String, CaseIterable {
    case activeScreen
    case primaryScreen
    case builtInScreen
}

enum OverlayPosition: String, CaseIterable {
    case top
    case bottom
}

// MARK: - Indicator Presets (Sprint 1 Simplification)

enum IndicatorPreset: String, CaseIterable {
    case minimal    // 仅波形
    case standard   // 波形 + 计时器
    case detailed   // 全信息（Profile + 波形 + 计时器）
    case custom     // 自定义模式

    var displayName: String {
        switch self {
        case .minimal:
            String(localized: "Minimal")
        case .standard:
            String(localized: "Standard")
        case .detailed:
            String(localized: "Detailed")
        case .custom:
            String(localized: "Custom")
        }
    }
}
