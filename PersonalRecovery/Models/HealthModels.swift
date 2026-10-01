import Foundation

// Plain value types that the rest of the app works with. Nothing in here imports
// HealthKit, so a future recovery algorithm can be unit-tested without a HealthKit store.

/// One measurement of a `HealthMetric`.
struct QuantitySample: Equatable, Sendable {
    let metric: HealthMetric
    let value: Double
    let startDate: Date
    let endDate: Date
}

/// A finished workout, reduced to the fields a recovery model is likely to need.
struct WorkoutSummary: Equatable, Sendable {
    let activityName: String
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    /// Active energy in kilocalories, if the workout recorded it.
    let activeEnergyKilocalories: Double?
}

/// Where the app stands with HealthKit permissions.
///
/// HealthKit deliberately hides whether the user granted or denied *read* access
/// (to stop apps inferring health conditions from a refusal). The only thing we can learn is
/// whether the permission sheet still needs to be shown, so that is all this models.
enum AuthorizationState: Equatable, Sendable {
    /// This device has no Health data (e.g. some iPad configurations).
    case unavailable
    /// The permission sheet has not been shown yet for every type we read.
    case shouldRequest
    /// The sheet has been shown. Individual types may still have been declined;
    /// that shows up as missing data, not as an error.
    case requested
    /// The status could not be determined (e.g. the device is locked).
    case unknown

    var title: String {
        switch self {
        case .unavailable: "Health data unavailable"
        case .shouldRequest: "Access not requested yet"
        case .requested: "Access requested"
        case .unknown: "Status unknown"
        }
    }
}

/// Loading state for one dashboard value. Each metric has its own state so one failing or
/// empty query never affects the others.
enum LoadState<Value> {
    case idle
    case loading
    case loaded(Value)
    /// The query succeeded but HealthKit holds nothing: no device, no permission, or no recent data.
    case noData
    case failed(String)
}

extension LoadState: Equatable where Value: Equatable {}
