import HealthKit

/// The single place in the app that talks to HealthKit.
///
/// ## Permissions
/// * The app is **read-only**: `requestAuthorization` passes an empty "share" set, so it can never
///   write to or modify Health data.
/// * Requires the HealthKit capability (`Config/PersonalRecovery.entitlements`) and
///   `NSHealthShareUsageDescription` (`Config/Info.plist`).
/// * HealthKit never reveals whether *read* access was granted. A query for a type the user
///   declined simply returns no results, exactly as if there were no data. So the UI treats
///   "no data" as a normal state and never as an error.
///
/// ## Queries
/// Uses the async query descriptors (`HKSampleQueryDescriptor`, `HKStatisticsQueryDescriptor`,
/// iOS 15.4+) instead of callback-based `HKSampleQuery`, so each read is a plain `await`.
///
/// `@unchecked Sendable` is sound here: the class is immutable after init and `HKHealthStore`
/// is documented as thread safe.
final class HealthKitManager: HealthDataProviding, @unchecked Sendable {

    private let healthStore = HKHealthStore()

    /// Every type we ask to read. Add new types here and they will be included in the next
    /// permission request (`authorizationState()` then reports `.shouldRequest` again).
    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = Set(HealthMetric.allCases.map { $0.quantityType })
        types.insert(HKCategoryType(.sleepAnalysis))
        types.insert(HKObjectType.workoutType())
        return types
    }

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Authorization

    func authorizationState() async -> AuthorizationState {
        guard isHealthDataAvailable else { return .unavailable }
        do {
            // Asks HealthKit whether the permission sheet would still be shown for `readTypes`.
            // This is the only authorization signal available for read-only access.
            let status = try await healthStore.statusForAuthorizationRequest(toShare: [], read: readTypes)
            switch status {
            case .shouldRequest: return .shouldRequest
            case .unnecessary: return .requested
            default: return .unknown
            }
        } catch {
            return .unknown
        }
    }

    func requestAuthorization() async throws {
        guard isHealthDataAvailable else { return }
        // Shows the system sheet the first time (and again only if new types were added).
        // Returning normally means the sheet was dismissed, NOT that access was granted.
        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
    }

    // MARK: - Quantity samples

    func latestSample(for metric: HealthMetric) async throws -> QuantitySample? {
        // Newest sample first, limited to one row: the cheapest way to get "latest value".
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: metric.quantityType)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 1
        )
        let results = try await descriptor.result(for: healthStore)
        return results.first.map { makeSample($0, metric: metric) }
    }

    func samples(for metric: HealthMetric, in interval: DateInterval) async throws -> [QuantitySample] {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: metric.quantityType, predicate: predicate(for: interval))],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let results = try await descriptor.result(for: healthStore)
        return results.map { makeSample($0, metric: metric) }
    }

    func totalActiveEnergy(in interval: DateInterval) async throws -> Double? {
        // A statistics query lets HealthKit sum the samples and de-duplicate overlapping sources
        // (watch vs. phone) for us, which a hand-written sum over raw samples would get wrong.
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(
                type: HealthMetric.activeEnergy.quantityType,
                predicate: predicate(for: interval)
            ),
            options: .cumulativeSum
        )
        let statistics = try await descriptor.result(for: healthStore)
        return statistics?.sumQuantity()?.doubleValue(for: HealthMetric.activeEnergy.unit)
    }

    // MARK: - Sleep

    func sleepSegments(in interval: DateInterval) async throws -> [SleepSegment] {
        // Sleep is a category type. Each sample is one block of a single stage
        // (in bed, awake, REM, core, deep, or unspecified asleep).
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: HKCategoryType(.sleepAnalysis), predicate: predicate(for: interval))],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let results = try await descriptor.result(for: healthStore)
        return results.compactMap { sample in
            guard let stage = Self.sleepStage(for: sample.value), sample.endDate > sample.startDate else {
                return nil
            }
            return SleepSegment(
                stage: stage,
                interval: DateInterval(start: sample.startDate, end: sample.endDate),
                sourceID: sample.sourceRevision.source.bundleIdentifier
            )
        }
    }

    // MARK: - Workouts

    func workouts(in interval: DateInterval) async throws -> [WorkoutSummary] {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate(for: interval))],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)]
        )
        let results = try await descriptor.result(for: healthStore)
        let energyType = HealthMetric.activeEnergy.quantityType
        return results.map { workout in
            WorkoutSummary(
                activityName: Self.name(for: workout.workoutActivityType),
                startDate: workout.startDate,
                endDate: workout.endDate,
                duration: workout.duration,
                activeEnergyKilocalories: workout.statistics(for: energyType)?
                    .sumQuantity()?
                    .doubleValue(for: HealthMetric.activeEnergy.unit)
            )
        }
    }

    // MARK: - Helpers

    /// Matches every sample that overlaps `interval`.
    private func predicate(for interval: DateInterval) -> NSPredicate {
        HKQuery.predicateForSamples(withStart: interval.start, end: interval.end, options: [])
    }

    private func makeSample(_ sample: HKQuantitySample, metric: HealthMetric) -> QuantitySample {
        QuantitySample(
            metric: metric,
            value: sample.quantity.doubleValue(for: metric.unit),
            startDate: sample.startDate,
            endDate: sample.endDate
        )
    }

    /// Maps HealthKit's raw sleep value to our stage. Unknown future values map to nil
    /// and are skipped rather than crashing.
    private static func sleepStage(for rawValue: Int) -> SleepStage? {
        switch HKCategoryValueSleepAnalysis(rawValue: rawValue) {
        case .inBed: .inBed
        case .awake: .awake
        case .asleepREM: .rem
        case .asleepCore: .core
        case .asleepDeep: .deep
        case .asleepUnspecified: .unspecified
        default: nil
        }
    }

    private static func name(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: "Running"
        case .walking: "Walking"
        case .cycling: "Cycling"
        case .swimming: "Swimming"
        case .hiking: "Hiking"
        case .yoga: "Yoga"
        case .functionalStrengthTraining, .traditionalStrengthTraining: "Strength Training"
        case .highIntensityIntervalTraining: "HIIT"
        case .elliptical: "Elliptical"
        case .rowing: "Rowing"
        default: "Workout"
        }
    }
}
