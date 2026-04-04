import Foundation

extension Date {
    /// Returns a human-readable relative time string (e.g. "刚刚", "5 min ago", "yesterday").
    /// Matches the logic previously inlined in HistoryView.RecordRow.
    func relativeTimeString() -> String {
        let seconds = Date().timeIntervalSince(self)
        let minutes = Int(seconds / 60)
        let hours = Int(seconds / 3600)
        let days = Int(seconds / 86400)

        if minutes < 1 {
            return String(localized: "just_now")
        } else if minutes < 60 {
            return String(localized: "\(minutes) min ago")
        } else if hours < 24 {
            return String(localized: "\(hours) hr ago")
        } else if Calendar.current.isDateInYesterday(self) {
            return String(localized: "yesterday")
        } else if days < 7 {
            return String(localized: "\(days) days ago")
        } else {
            return formatted(.dateTime.day().month(.abbreviated))
        }
    }

    /// Returns the time portion as "HH:mm:ss" (e.g. "14:30:05").
    /// This is a new utility -- HistoryView previously only had m:ss formatting
    /// via `formatTime(_:)` on TimeInterval. This provides the full HH:mm:ss form.
    func timeString() -> String {
        formatted(.dateTime.hour().minute().second())
    }
}

extension Double {
    /// Formats a duration in seconds as a compact string (e.g. "45s", "1m 30s").
    /// Matches the logic previously inlined in HistoryView.RecordRow and RecordDetailView.
    var durationString: String {
        let s = Int(self)
        if s < 60 { return "\(s)s" }
        return "\(s / 60)m \(s % 60)s"
    }

    /// Formats a time interval as "m:ss" (e.g. "1:30", "0:05").
    /// Matches the logic previously inlined in HistoryView.AudioPlaybackBar.formatTime(_:).
    var playbackTimeString: String {
        let s = Int(self)
        let m = s / 60
        let r = s % 60
        return String(format: "%d:%02d", m, r)
    }
}
