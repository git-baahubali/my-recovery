import Foundation

/// Everything the app needs from Apple Health, expressed in plain value types.
///
/// View models and (later) the recovery algorithm depend on this protocol, not on
/// `HealthKitManager`, so they can be tested with a stand-in that lives in the test target.
protocol HealthDataProviding: Sendable {
    /// False on devices without Health data.
    var isHealthDataAvailable: Bool { get }

    /// Whether the permission sheet still needs to be shown. Never throws.
    func authorizationState() async -> AuthorizationState

    /// Presents the HealthKit permission sheet if there is anything left to ask.
    func requestAuthorization() async throws

    /// Most recent sample of a metric, or nil if HealthKit has none.
    func latestSample(for metric: HealthMetric) async throws -> QuantitySample?

    /// All samples of a metric in `interval`, oldest first.
    func samples(for metric: HealthMetric, in interval: DateInterval) async throws -> [QuantitySample]

    /// Sleep segments overlapping `interval`, oldest first.
    func sleepSegments(in interval: DateInterval) async throws -> [SleepSegment]

    /// Workouts overlapping `interval`, most recent first.
    func workouts(in interval: DateInterval) async throws -> [WorkoutSummary]

    /// Total active energy (kcal) in `interval`, or nil if there is no data.
    func totalActiveEnergy(in interval: DateInterval) async throws -> Double?
}
