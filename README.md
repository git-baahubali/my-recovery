# PersonalRecovery

A private iOS app that reads Apple Watch recovery/sleep data from HealthKit and shows it on a dashboard.
Personal use only: no backend, no cloud, no analytics, no third-party dependencies. All processing is on-device.

**Status:** v0.1 — architecture and dashboard only. The recovery algorithm is not implemented yet.

## Requirements

- Mac with Xcode 16 or later
- iPhone running iOS 18+, paired with an Apple Watch
- A free Apple ID (Personal Team) signed in to Xcode

## Run on your iPhone

1. Open `PersonalRecovery.xcodeproj` in Xcode.
2. Xcode menu › **Settings › Accounts**: add your Apple ID if it isn't listed.
3. Select the **PersonalRecovery** project in the navigator › target **PersonalRecovery** › **Signing & Capabilities**:
   - Tick **Automatically manage signing**.
   - **Team**: choose your *Personal Team*.
   - **Bundle Identifier**: change `dev.personal.PersonalRecovery` to something unique to you
     (e.g. `com.yourname.PersonalRecovery`). Free accounts can't reuse an ID another account has claimed.
   - The **HealthKit** capability should already appear. If not, click **+ Capability** › **HealthKit**.
4. On the iPhone: **Settings › Privacy & Security › Developer Mode** › on (restart when asked). The toggle only
   appears after you've tried to run an app from Xcode once.
5. Connect the iPhone with a cable (or enable wireless debugging), unlock it, tap **Trust This Computer**.
6. Choose your iPhone in the Xcode run destination (top toolbar) and press **⌘R**.
7. First launch only: on the iPhone go to **Settings › General › VPN & Device Management**, tap your Apple ID
   under *Developer App*, and tap **Trust**. Launch the app again.
8. The HealthKit permission sheet appears. Turn on **all categories** and tap **Allow**.

Free-account builds expire after **7 days**; press ⌘R again from Xcode to reinstall.

The simulator works too, but it has no Health data, so every card shows "No data available".

## Tests

Press **⌘U** in Xcode. The tests cover the sleep aggregation logic (`SleepSummaryBuilder`, `SleepWindow`).

## Architecture

```
Config/                       Info.plist (HealthKit usage text) and entitlements
PersonalRecovery/
  HealthKit/
    HealthDataProviding.swift Protocol: everything the app needs from Health
    HealthKitManager.swift    The only file that imports HealthKit queries (async/await)
  Models/                     Plain value types (no HealthKit): metrics, samples, sleep, load state
  ViewModels/                 DashboardViewModel (@Observable, @MainActor)
  Views/                      SwiftUI dashboard and cards
PersonalRecoveryTests/
```

Data flow: `HealthKitManager` → `HealthDataProviding` → `DashboardViewModel` → SwiftUI views.
A future recovery algorithm should depend on `HealthDataProviding` and the value types in `Models/`,
which keeps it testable without HealthKit.

## HealthKit notes

- The app is read-only; it never writes to Health.
- HealthKit hides whether *read* access was granted. A declined type looks identical to "no data", so the UI
  treats missing data as a normal state.
- Already read by `HealthKitManager` but not yet shown: heart rate, respiratory rate, wrist temperature,
  workouts, active energy.
- Wrist temperature needs Apple Watch Series 8 / Ultra or later.
