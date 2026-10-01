import SwiftUI

/// Rounded container with a title row, shared by every dashboard card.
struct Card<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

/// Explains why a value is missing. "No data" is normal, so it is phrased as information, not an error.
private struct NoDataView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("No data available")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Apple Watch hasn't recorded this yet, or access was not granted. You can review access in Settings › Health › Data Access & Devices › Personal Recovery.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

private struct FailedView: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Couldn't load")
                .font(.title3.weight(.semibold))
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

struct AuthorizationCard: View {
    let state: AuthorizationState
    let errorMessage: String?
    let onRequest: () -> Void

    var body: some View {
        Card(title: "Health Access", systemImage: "lock.shield") {
            Text(state.title)
                .font(.title3.weight(.semibold))

            switch state {
            case .unavailable:
                Text("Health data isn't available on this device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            case .shouldRequest, .unknown:
                Button("Allow Health Access", action: onRequest)
                    .buttonStyle(.borderedProminent)
            case .requested:
                Text("Apple doesn't tell apps which read permissions were granted. Anything missing below means no data or access turned off.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }
}

/// Card showing the latest value of one quantity metric.
struct MetricCard: View {
    let title: String
    let systemImage: String
    let unitLabel: String
    let state: LoadState<QuantitySample>

    var body: some View {
        Card(title: title, systemImage: systemImage) {
            switch state {
            case .idle, .loading:
                ProgressView()
            case .loaded(let sample):
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(sample.valueText)
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                        Text(unitLabel)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    Text(sample.measuredText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            case .noData:
                NoDataView()
            case .failed(let message):
                FailedView(message: message)
            }
        }
    }
}

/// Card showing last night's total sleep and, when available, the stage breakdown.
struct SleepCard: View {
    let state: LoadState<SleepSummary>

    /// Display order, lightest to deepest.
    private static let stageOrder: [SleepStage] = [.awake, .rem, .core, .deep, .unspecified]

    var body: some View {
        Card(title: "Last Night's Sleep", systemImage: "bed.double.fill") {
            switch state {
            case .idle, .loading:
                ProgressView()
            case .loaded(let summary):
                loadedContent(summary)
            case .noData:
                NoDataView()
            case .failed(let message):
                FailedView(message: message)
            }
        }
    }

    @ViewBuilder
    private func loadedContent(_ summary: SleepSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(summary.totalAsleep.hoursMinutesText)
                .font(.system(size: 40, weight: .bold, design: .rounded))
            Text("\(summary.start.formatted(date: .abbreviated, time: .shortened)) – \(summary.end.formatted(date: .omitted, time: .shortened))")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }

        if summary.hasStageBreakdown {
            let total = summary.stageDurations.values.reduce(0, +)
            VStack(spacing: 8) {
                ForEach(Self.stageOrder, id: \.self) { stage in
                    if let duration = summary.stageDurations[stage] {
                        StageRow(stage: stage, duration: duration, fraction: total > 0 ? duration / total : 0)
                    }
                }
            }
        } else {
            Text("Sleep stages aren't available for this night.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

private struct StageRow: View {
    let stage: SleepStage
    let duration: TimeInterval
    /// Share of the night, 0...1.
    let fraction: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(stage.displayName)
                Spacer()
                Text(duration.hoursMinutesText)
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)

            GeometryReader { proxy in
                Capsule()
                    .fill(Color(.tertiarySystemFill))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(color)
                            .frame(width: proxy.size.width * fraction)
                    }
            }
            .frame(height: 6)
        }
    }

    private var color: Color {
        switch stage {
        case .awake: .orange
        case .rem: .cyan
        case .core: .blue
        case .deep: .indigo
        case .unspecified, .inBed: .gray
        }
    }
}
