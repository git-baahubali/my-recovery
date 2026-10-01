import HealthKit

/// The quantity-based metrics the app knows how to read.
///
/// Each case maps to one HealthKit quantity type plus the unit we always convert to,
/// so the rest of the app only ever deals with plain `Double`s in a known unit.
/// Sleep and workouts are not quantities and are modelled separately
/// (see `SleepSegment` and `WorkoutSummary`).
enum HealthMetric: CaseIterable, Sendable {
    case heartRate
    case heartRateVariability
    case restingHeartRate
    case respiratoryRate
    /// Apple Watch Series 8 / Ultra and later, measured while asleep. Older watches never
    /// produce this, so "no data" is a normal outcome and must not be treated as an error.
    case wristTemperature
    case activeEnergy

    var quantityType: HKQuantityType {
        switch self {
        case .heartRate: HKQuantityType(.heartRate)
        case .heartRateVariability: HKQuantityType(.heartRateVariabilitySDNN)
        case .restingHeartRate: HKQuantityType(.restingHeartRate)
        case .respiratoryRate: HKQuantityType(.respiratoryRate)
        case .wristTemperature: HKQuantityType(.appleSleepingWristTemperature)
        case .activeEnergy: HKQuantityType(.activeEnergyBurned)
        }
    }

    /// Unit used when reading values out of HealthKit.
    var unit: HKUnit {
        switch self {
        case .heartRate, .restingHeartRate, .respiratoryRate:
            HKUnit.count().unitDivided(by: .minute())
        case .heartRateVariability:
            HKUnit.secondUnit(with: .milli)
        case .wristTemperature:
            HKUnit.degreeCelsius()
        case .activeEnergy:
            HKUnit.kilocalorie()
        }
    }

    var displayName: String {
        switch self {
        case .heartRate: "Heart Rate"
        case .heartRateVariability: "Heart Rate Variability"
        case .restingHeartRate: "Resting Heart Rate"
        case .respiratoryRate: "Respiratory Rate"
        case .wristTemperature: "Wrist Temperature"
        case .activeEnergy: "Active Energy"
        }
    }

    /// Short unit label for display.
    var unitLabel: String {
        switch self {
        case .heartRate, .restingHeartRate: "bpm"
        case .heartRateVariability: "ms"
        case .respiratoryRate: "br/min"
        case .wristTemperature: "°C"
        case .activeEnergy: "kcal"
        }
    }
}
