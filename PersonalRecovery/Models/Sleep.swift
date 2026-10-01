import Foundation

/// Sleep stage, independent of HealthKit's category values.
enum SleepStage: String, CaseIterable, Sendable {
    case inBed
    case awake
    case rem
    case core
    case deep
    /// Asleep, but the source did not report a stage (older watchOS, third-party apps).
    case unspecified

    var isAsleep: Bool {
        switch self {
        case .rem, .core, .deep, .unspecified: true
        case .inBed, .awake: false
        }
    }

    var displayName: String {
        switch self {
        case .inBed: "In Bed"
        case .awake: "Awake"
        case .rem: "REM"
        case .core: "Core"
        case .deep: "Deep"
        case .unspecified: "Asleep (unspecified)"
        }
    }
}

/// One contiguous block of a single sleep stage, as recorded by one source.
struct SleepSegment: Equatable, Sendable {
    let stage: SleepStage
    let interval: DateInterval
    /// Bundle identifier of the app/device that wrote the sample.
    let sourceID: String
}

/// Aggregated view of one night's sleep.
struct SleepSummary: Equatable, Sendable {
    let start: Date
    let end: Date
    /// Time actually asleep (all asleep stages, overlaps counted once).
    let totalAsleep: TimeInterval
    /// Time spent in each stage. Only stages with a non-zero duration are present.
    let stageDurations: [SleepStage: TimeInterval]

    /// True when the source reported REM/Core/Deep rather than just "asleep".
    var hasStageBreakdown: Bool {
        [SleepStage.rem, .core, .deep].contains { (stageDurations[$0] ?? 0) > 0 }
    }
}

/// The time range searched for "last night's" sleep.
enum SleepWindow {
    /// From 18:00 the previous evening until `now`.
    ///
    /// Anchoring on the evening rather than midnight keeps a night that started at 23:00
    /// and ended at 07:00 in one piece. Daytime naps inside the window are included
    /// in the totals; a smarter night-vs-nap split belongs in the recovery algorithm.
    static func lastNight(endingAt now: Date, calendar: Calendar = .current) -> DateInterval {
        let startOfToday = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday
        let start = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: yesterday) ?? yesterday
        return DateInterval(start: start, end: max(now, start))
    }
}

/// Turns raw sleep segments into a `SleepSummary`.
///
/// Pure logic with no HealthKit dependency, so it is unit tested.
enum SleepSummaryBuilder {

    /// Returns nil when there is no asleep time at all.
    ///
    /// iPhone, Apple Watch and third-party apps can all write overlapping sleep samples for the
    /// same night. Summing everything would double count, so we keep only the source that recorded
    /// the most sleep and merge overlaps within it.
    static func summarize(_ segments: [SleepSegment]) -> SleepSummary? {
        let candidates = segments.filter { $0.stage != .inBed }

        let asleepBySource = Dictionary(grouping: candidates.filter { $0.stage.isAsleep }, by: \.sourceID)
            .mapValues { unionDuration(of: $0.map(\.interval)) }
        guard let primarySource = asleepBySource.max(by: { $0.value < $1.value })?.key else {
            return nil
        }

        let chosen = candidates.filter { $0.sourceID == primarySource }
        guard let start = chosen.map(\.interval.start).min(),
              let end = chosen.map(\.interval.end).max() else {
            return nil
        }

        var stageDurations: [SleepStage: TimeInterval] = [:]
        for (stage, group) in Dictionary(grouping: chosen, by: \.stage) {
            let duration = unionDuration(of: group.map(\.interval))
            if duration > 0 { stageDurations[stage] = duration }
        }

        let totalAsleep = unionDuration(of: chosen.filter { $0.stage.isAsleep }.map(\.interval))
        return SleepSummary(start: start, end: end, totalAsleep: totalAsleep, stageDurations: stageDurations)
    }

    /// Total length covered by `intervals`, counting overlapping stretches once.
    static func unionDuration(of intervals: [DateInterval]) -> TimeInterval {
        let sorted = intervals.sorted { $0.start < $1.start }
        guard var current = sorted.first else { return 0 }

        var total: TimeInterval = 0
        for interval in sorted.dropFirst() {
            if interval.start <= current.end {
                if interval.end > current.end {
                    current = DateInterval(start: current.start, end: interval.end)
                }
            } else {
                total += current.duration
                current = interval
            }
        }
        return total + current.duration
    }
}
