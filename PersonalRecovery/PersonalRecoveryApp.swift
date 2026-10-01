import SwiftUI

@main
struct PersonalRecoveryApp: App {
    /// The only place the concrete HealthKit implementation is chosen.
    @State private var viewModel = DashboardViewModel(healthData: HealthKitManager())

    var body: some Scene {
        WindowGroup {
            DashboardView(viewModel: viewModel)
        }
    }
}
