import XCTest
@testable import DavyWhisper

final class FormattingUtilitiesTests: XCTestCase {

    // MARK: - Date.relativeTimeString()

    func testRelativeTimeString_JustNow() {
        // Less than 60 seconds ago should produce a non-empty localized string
        let now = Date()
        let result = now.relativeTimeString()
        XCTAssertFalse(result.isEmpty)
    }

    func testRelativeTimeString_LessThanOneMinute() {
        // 30 seconds ago is still "just now" (minutes < 1)
        let date = Date().addingTimeInterval(-30)
        let result = date.relativeTimeString()
        // Both should resolve the same localization key "just_now"
        XCTAssertEqual(result, Date().relativeTimeString())
    }

    func testRelativeTimeString_MinutesAgo() {
        // 5 minutes ago
        let date = Date().addingTimeInterval(-5 * 60)
        let result = date.relativeTimeString()
        // Should contain "5" in the output (localized as "5 分钟前" or "5 min ago")
        XCTAssertTrue(result.contains("5"), "Expected result to contain '5', got: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    func testRelativeTimeString_59MinutesAgo() {
        // 59 minutes ago
        let date = Date().addingTimeInterval(-59 * 60)
        let result = date.relativeTimeString()
        XCTAssertTrue(result.contains("59"), "Expected result to contain '59', got: \(result)")
    }

    func testRelativeTimeString_HoursAgo() {
        // 3 hours ago
        let date = Date().addingTimeInterval(-3 * 3600)
        let result = date.relativeTimeString()
        XCTAssertTrue(result.contains("3"), "Expected result to contain '3', got: \(result)")
    }

    func testRelativeTimeString_23HoursAgo() {
        // 23 hours ago
        let date = Date().addingTimeInterval(-23 * 3600)
        let result = date.relativeTimeString()
        XCTAssertTrue(result.contains("23"), "Expected result to contain '23', got: \(result)")
    }

    func testRelativeTimeString_Yesterday() {
        // A date that Calendar considers "yesterday"
        let yesterday = Calendar.current.date(
            byAdding: .day,
            value: -1,
            to: Calendar.current.startOfDay(for: Date())
        )!
        let result = yesterday.relativeTimeString()
        XCTAssertFalse(result.isEmpty)
    }

    func testRelativeTimeString_DaysAgo() {
        // 3 days ago (not yesterday)
        let date = Date().addingTimeInterval(-3 * 86400)
        let result = date.relativeTimeString()
        XCTAssertTrue(result.contains("3"), "Expected result to contain '3', got: \(result)")
    }

    func testRelativeTimeString_SixDaysAgo() {
        // 6 days ago
        let date = Date().addingTimeInterval(-6 * 86400)
        let result = date.relativeTimeString()
        XCTAssertTrue(result.contains("6"), "Expected result to contain '6', got: \(result)")
    }

    func testRelativeTimeString_OverAWeekAgo() {
        // 10 days ago should produce a formatted date string (day + abbreviated month)
        let date = Date().addingTimeInterval(-10 * 86400)
        let result = date.relativeTimeString()
        let expected = date.formatted(.dateTime.day().month(.abbreviated))
        XCTAssertEqual(result, expected)
    }

    func testRelativeTimeString_Progression() {
        // Verify the progression: just now < minutes < hours < days < formatted date
        let now = Date()
        let justNow = now.relativeTimeString()
        let fiveMin = now.addingTimeInterval(-5 * 60).relativeTimeString()
        let threeHr = now.addingTimeInterval(-3 * 3600).relativeTimeString()

        // All should be non-empty and distinct
        XCTAssertFalse(justNow.isEmpty)
        XCTAssertFalse(fiveMin.isEmpty)
        XCTAssertFalse(threeHr.isEmpty)
        XCTAssertNotEqual(justNow, fiveMin)
        XCTAssertNotEqual(fiveMin, threeHr)
    }

    // MARK: - Double.durationString

    func testDurationString_ZeroSeconds() {
        XCTAssertEqual(0.0.durationString, "0s")
    }

    func testDurationString_30Seconds() {
        XCTAssertEqual(30.0.durationString, "30s")
    }

    func testDurationString_59Seconds() {
        XCTAssertEqual(59.0.durationString, "59s")
    }

    func testDurationString_60Seconds() {
        XCTAssertEqual(60.0.durationString, "1m 0s")
    }

    func testDurationString_90Seconds() {
        XCTAssertEqual(90.0.durationString, "1m 30s")
    }

    func testDurationString_OneHour() {
        XCTAssertEqual(3600.0.durationString, "60m 0s")
    }

    func testDurationString_OneHourOneSecond() {
        XCTAssertEqual(3661.0.durationString, "61m 1s")
    }

    func testDurationString_FractionalSeconds() {
        // 45.9 seconds should truncate to 45s (Int truncation)
        XCTAssertEqual(45.9.durationString, "45s")
    }

    func testDurationString_LargeValue() {
        XCTAssertEqual(7384.0.durationString, "123m 4s")
    }

    // MARK: - Double.playbackTimeString

    func testPlaybackTimeString_Zero() {
        XCTAssertEqual(0.0.playbackTimeString, "0:00")
    }

    func testPlaybackTimeString_FiveSeconds() {
        XCTAssertEqual(5.0.playbackTimeString, "0:05")
    }

    func testPlaybackTimeString_ThirtySeconds() {
        XCTAssertEqual(30.0.playbackTimeString, "0:30")
    }

    func testPlaybackTimeString_OneMinute() {
        XCTAssertEqual(60.0.playbackTimeString, "1:00")
    }

    func testPlaybackTimeString_OneMinuteThirtySeconds() {
        XCTAssertEqual(90.0.playbackTimeString, "1:30")
    }

    func testPlaybackTimeString_TenMinutesFiveSeconds() {
        XCTAssertEqual(605.0.playbackTimeString, "10:05")
    }

    func testPlaybackTimeString_LargeValue() {
        XCTAssertEqual(3661.0.playbackTimeString, "61:01")
    }

    func testPlaybackTimeString_FractionalTruncation() {
        XCTAssertEqual(59.9.playbackTimeString, "0:59")
    }

    // MARK: - Date.timeString()

    func testTimeString_NonEmpty() {
        let date = Date()
        let result = date.timeString()
        XCTAssertFalse(result.isEmpty)
    }

    func testTimeString_ContainsSeparators() {
        // The formatted output should contain digits for time representation
        let date = Date()
        let result = date.timeString()
        let hasDigit = result.unicodeScalars.contains { CharacterSet.decimalDigits.contains($0) }
        XCTAssertTrue(hasDigit, "timeString should contain at least one digit")
    }
}
