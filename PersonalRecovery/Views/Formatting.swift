import Foundation

extension TimeInterval {
    /// "7h 32m", or "45m" when under an hour.
    var hoursMinutesText: String {
        let totalMinutes = Int((self / 60).rounded())
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
}

extension QuantitySample {
    /// Value rounded for display, e.g. "48".
    var valueText: String {
        let digits = metric == .wristTemperature ? 1 : 0
        return value.formatted(.number.precision(.fractionLength(digits)))
    }

    /// "2 hours ago", "yesterday", etc.
    var measuredText: String {
        "Measured " + endDate.formatted(.relative(presentation: .named))
    }
}
