import Foundation
import Observation

/// Drives the dashboard. Owns no HealthKit types; it talks to `HealthDataProviding`.
///
/// Every metric loads independently and reports its own `LoadState`, so a failure or an empty
/// result in one place (say, no wrist temperature on an older watch) never blanks the rest.
@MainActor
@Observable
final class DashboardViewModel {

    private(set) var authorization: AuthorizationState = .unknown
    private(set) var hrv: LoadState<QuantitySample> = .idle
    private(set) var restingHeartRate: LoadState<QuantitySample> = .idle
    private(set) var sleep: LoadState<SleepSummary> = .idle
    /// Set when the permission request itself threw.
    private(set) var authorizationError: String?

    private let healthData: HealthDataProviding
    private var hasAutoRequestedAuthorization = false

    init(healthData: HealthDataProviding) {
        self.healthData = healthData
    }

    /// Called when the dashboard first appears: asks for permission once if it has never been
    /// asked, then loads data.
    func start() async {
        authorization = await healthData.authorizationState()
        if authorization == .shouldRequest, !hasAutoRequestedAuthorization {
            hasAutoRequestedAuthorization = true
            await requestAuthorization()
        } else {
            await refresh()
        }
    }

    /// Shows the HealthKit sheet (if still needed), then reloads everything.
    func requestAuthorization() async {
        authorizationError = nil
        do {
            try await healthData.requestAuthorization()
        } catch {
            authorizationError = error.localizedDescription
        }
        await refresh()
    }

    /// Reloads all dashboard values. Safe to call repeatedly (pull-to-refresh, returning to foreground).
    func refresh() async {
        authorization = await healthData.authorizationState()
        guard authorization != .unavailable else { return }

        hrv.beginLoadingIfIdle()
        restingHeartRate.beginLoadingIfIdle()
        sleep.beginLoadingIfIdle()

        // Capture locals so the concurrent child tasks do not touch main-actor state.
        let provider = healthData
        let window = SleepWindow.lastNight(endingAt: Date())

        async let hrvResult = Self.load {
            try await provider.latestSample(for: .heartRateVariability)
        }
        async let restingResult = Self.load {
            try await provider.latestSample(for: .restingHeartRate)
        }
        async let sleepResult = Self.load {
            let segments = try await provider.sleepSegments(in: window)
            return SleepSummaryBuilder.summarize(segments)
        }

        hrv = await hrvResult
        restingHeartRate = await restingResult
        sleep = await sleepResult
    }

    /// Runs one query and converts the outcome to a `LoadState`: nil becomes `.noData`,
    /// a thrown error becomes `.failed`. Never throws.
    private nonisolated static func load<Value: Sendable>(
        _ work: @Sendable () async throws -> Value?
    ) async -> LoadState<Value> {
        do {
            if let value = try await work() {
                return .loaded(value)
            }
            return .noData
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}

private extension LoadState {
    /// Shows a spinner on first load only; on later refreshes the previous value stays visible.
    mutating func beginLoadingIfIdle() {
        if case .idle = self { self = .loading }
    }
}
