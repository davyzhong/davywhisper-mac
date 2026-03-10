import Foundation

enum OverlayPosition: String, CaseIterable {
    case top
    case bottom
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
