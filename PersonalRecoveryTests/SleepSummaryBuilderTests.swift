import XCTest
@testable import PersonalRecovery

/// Tests the pure sleep-aggregation logic. The segments below are synthetic inputs built
/// for the tests only; no sample data exists in the app itself.
final class SleepSummaryBuilderTests: XCTestCase {

    private let base = Date(timeIntervalSinceReferenceDate: 0)

    private func segment(_ stage: SleepStage, from startHour: Double, to endHour: Double, source: String = "watch") -> SleepSegment {
        SleepSegment(
            stage: stage,
            interval: DateInterval(start: base.addingTimeInterval(startHour * 3600),
                                   end: base.addingTimeInterval(endHour * 3600)),
            sourceID: source
        )
    }

    func testEmptyInputReturnsNil() {
        XCTAssertNil(SleepSummaryBuilder.summarize([]))
    }

    func testInBedAndAwakeOnlyReturnsNil() {
        let segments = [segment(.inBed, from: 0, to: 8), segment(.awake, from: 1, to: 2)]
        XCTAssertNil(SleepSummaryBuilder.summarize(segments))
    }

    func testStageDurationsAndTotalAsleep() throws {
        let segments = [
            segment(.core, from: 0, to: 3),
            segment(.deep, from: 3, to: 4),
            segment(.awake, from: 4, to: 4.5),
            segment(.rem, from: 4.5, to: 6),
        ]
        let summary = try XCTUnwrap(SleepSummaryBuilder.summarize(segments))

        XCTAssertEqual(summary.totalAsleep, 5.5 * 3600, accuracy: 0.001)
        XCTAssertEqual(summary.stageDurations[.core], 3 * 3600)
        XCTAssertEqual(summary.stageDurations[.deep], 1 * 3600)
        XCTAssertEqual(summary.stageDurations[.rem], 1.5 * 3600)
        XCTAssertEqual(summary.stageDurations[.awake], 0.5 * 3600)
        XCTAssertTrue(summary.hasStageBreakdown)
        XCTAssertEqual(summary.start, base)
        XCTAssertEqual(summary.end, base.addingTimeInterval(6 * 3600))
    }

    func testUnspecifiedSleepHasNoStageBreakdown() throws {
        let summary = try XCTUnwrap(SleepSummaryBuilder.summarize([segment(.unspecified, from: 0, to: 7)]))
        XCTAssertEqual(summary.totalAsleep, 7 * 3600, accuracy: 0.001)
        XCTAssertFalse(summary.hasStageBreakdown)
    }

    func testOverlappingSourcesAreNotDoubleCounted() throws {
        let segments = [
            segment(.core, from: 0, to: 7, source: "watch"),
            segment(.unspecified, from: 0, to: 6, source: "thirdparty"),
        ]
        let summary = try XCTUnwrap(SleepSummaryBuilder.summarize(segments))
        XCTAssertEqual(summary.totalAsleep, 7 * 3600, accuracy: 0.001)
    }

    func testOverlappingSegmentsWithinOneSourceAreMerged() {
        let intervals = [
            DateInterval(start: base, end: base.addingTimeInterval(3600)),
            DateInterval(start: base.addingTimeInterval(1800), end: base.addingTimeInterval(7200)),
            DateInterval(start: base.addingTimeInterval(10_000), end: base.addingTimeInterval(10_600)),
        ]
        XCTAssertEqual(SleepSummaryBuilder.unionDuration(of: intervals), 7200 + 600, accuracy: 0.001)
    }

    func testLastNightWindowStartsPreviousEvening() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 7, minute: 30)))

        let window = SleepWindow.lastNight(endingAt: now, calendar: calendar)

        let expectedStart = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 9, hour: 18)))
        XCTAssertEqual(window.start, expectedStart)
        XCTAssertEqual(window.end, now)
    }
}
