import SwiftUI

struct DashboardView: View {
    let viewModel: DashboardViewModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    AuthorizationCard(
                        state: viewModel.authorization,
                        errorMessage: viewModel.authorizationError,
                        onRequest: { Task { await viewModel.requestAuthorization() } }
                    )

                    if viewModel.authorization != .unavailable {
                        MetricCard(
                            title: "Heart Rate Variability",
                            systemImage: "waveform.path.ecg",
                            unitLabel: "ms",
                            state: viewModel.hrv
                        )
                        MetricCard(
                            title: "Resting Heart Rate",
                            systemImage: "heart.fill",
                            unitLabel: "bpm",
                            state: viewModel.restingHeartRate
                        )
                        SleepCard(state: viewModel.sleep)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Recovery")
            .refreshable { await viewModel.refresh() }
        }
        .task { await viewModel.start() }
        .onChange(of: scenePhase) { _, phase in
            // Pick up data the Watch synced while the app was in the background.
            if phase == .active {
                Task { await viewModel.refresh() }
            }
        }
    }
}
