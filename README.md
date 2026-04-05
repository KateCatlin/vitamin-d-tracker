# ☀️ Vitamin D Tracker

A native iPhone app that helps you estimate your current vitamin D level over time using your home city, lab test results, daily supplements, and tracked sun exposure sessions.

> **⚠️ Disclaimer:** This app provides rough estimates only. It is NOT medical advice and should NOT be used for diagnosis or treatment. Consult a healthcare provider for vitamin D testing and supplementation guidance.

---

## Features

### 🏠 Smart Onboarding
- Select your home city for UV and baseline estimation
- Enter a recent vitamin D blood test result (if available)
- Set your daily supplement dose and type (D2 or D3)
- Clear medical disclaimer and model explanation

### 📊 Dashboard
- Estimated current vitamin D level with large, clear display
- Source label showing whether the value is measured or estimated
- Confidence indicator (High/Moderate/Low)
- Baseline and supplement summary cards
- Most recent sun session summary

### ☀️ Sun Exposure Tracking
- Start/stop sun exposure sessions with live timer
- Adjustable skin exposure and cloud cover sliders
- Real-time vitamin D gain estimation
- UV risk level indicator
- Sunburn warning with alert when recommended exposure is exceeded
- Session summary with total vitamin D gained

### ⚙️ Settings
- Change home city
- Enter new lab test results (resets the model anchor)
- Update supplement dose and type (forward-only changes)
- View model assumptions
- View medical disclaimer

### 🔬 Evidence-Based Model
- 21-day half-life decay model for circulating 25(OH)D
- Dose-response supplementation model
- D2 vs D3 effectiveness difference (D2 ≈ 50% of D3)
- Sun exposure production based on UV index, skin exposure, cloud cover, and duration
- UV/sunburn risk using Standard Erythemal Dose (SED) model
- Geographic + seasonal baseline estimation

See [MODELING.md](MODELING.md) for complete scientific methodology and references.

---

## Architecture

### Technology Stack
- **Language:** Swift
- **UI Framework:** SwiftUI
- **Target:** iOS 17+
- **Architecture:** MVVM (Model-View-ViewModel)
- **Persistence:** UserDefaults with JSON encoding
- **Testing:** XCTest via Swift Package Manager

### Project Structure

```
vitamin-d-tracker/
├── Package.swift                          # SPM for testable core library
├── README.md                              # This file
├── MODELING.md                            # Scientific model documentation
│
├── Sources/VitaminDTrackerCore/           # Core business logic (SPM library)
│   ├── Models/
│   │   ├── UserProfile.swift              # User profile and onboarding state
│   │   ├── HomeLocation.swift             # City/coordinates + city database
│   │   ├── VitaminDTestResult.swift       # Lab test results with unit support
│   │   ├── SupplementPlan.swift           # Supplement dose and type
│   │   ├── SunExposureSession.swift       # Sun session tracking data
│   │   ├── VitaminDStateEstimate.swift    # Point-in-time level estimate
│   │   ├── ModelingAssumptions.swift      # Scientific constants and config
│   │   └── DailyUpdateEvent.swift         # Daily decay/supplement/sun record
│   ├── Services/
│   │   ├── VitaminDModel.swift            # Core estimation engine
│   │   ├── BaselineEstimator.swift        # Geographic + seasonal baseline
│   │   ├── SunExposureCalculator.swift    # Sun → vitamin D production
│   │   ├── UVRiskCalculator.swift         # Sunburn/UV risk assessment
│   │   └── DailyUpdateService.swift       # Catch-up and lab result handling
│   └── Utilities/
│       └── UnitConversion.swift           # ng/mL ↔ nmol/L, IU ↔ µg
│
├── Tests/VitaminDTrackerCoreTests/        # Comprehensive test suite
│   ├── VitaminDModelTests.swift           # Decay, supplement, multi-day tests
│   ├── SunExposureCalculatorTests.swift   # Sun production + diminishing returns
│   ├── UVRiskCalculatorTests.swift        # Risk levels, SED, overexposure
│   ├── BaselineEstimatorTests.swift       # Geographic + seasonal estimation
│   ├── DailyUpdateServiceTests.swift      # Catch-up, lab anchoring, correctness
│   └── UnitConversionTests.swift          # Unit conversion round-trips
│
└── VitaminDTracker/                       # SwiftUI app (requires Xcode)
    ├── App/
    │   └── VitaminDTrackerApp.swift       # @main entry point
    ├── Views/
    │   ├── ContentView.swift              # Root view + tab navigation
    │   ├── Onboarding/                    # 5-step onboarding flow
    │   ├── Dashboard/                     # Main dashboard screen
    │   ├── SunSession/                    # Sun exposure tracking screen
    │   ├── Settings/                      # Settings + profile screen
    │   └── Components/
    │       └── DesignSystem.swift         # Colors, typography, card styles
    ├── ViewModels/
    │   ├── OnboardingViewModel.swift
    │   ├── DashboardViewModel.swift
    │   ├── SunSessionViewModel.swift
    │   └── SettingsViewModel.swift
    ├── Storage/
    │   └── PersistenceManager.swift       # Local JSON + UserDefaults persistence
    └── Analytics/
        └── AnalyticsService.swift         # Lightweight local event tracking
```

### Key Design Decisions

1. **SPM Core Library**: All testable business logic (models, services, calculations) lives in a Swift Package that can be tested on any platform with `swift test`.

2. **MVVM Architecture**: Views are thin, view models coordinate between views and services, and the core library handles all calculations.

3. **Forward-Only Changes**: Supplement changes apply from the change date forward only. Historical estimates are preserved.

4. **Event-Based Recalculation**: The current estimate can always be recomputed from the anchor point (lab test or baseline) plus all recorded events.

5. **Catch-Up on App Open**: If daily background updates are missed, the app replays all missing days when opened, ensuring the estimate is always current.

---

## Setup and Development

### Prerequisites
- Xcode 15+ (for iOS app development)
- Swift 5.9+ (available via Xcode or standalone Swift toolchain)
- macOS 14+ (for Xcode 15)

### Running Tests (Command Line)

The core business logic tests can be run without Xcode:

```bash
swift test
```

This runs 81 tests covering:
- Supplement effect calculations
- D2 vs D3 difference behavior
- Decay logic (half-life, multi-day)
- Event-forward recalculation
- Sun session contribution logic
- Unit conversions (ng/mL ↔ nmol/L, IU ↔ µg)
- Overdue daily catch-up logic
- Baseline estimation (latitude + season)
- UV risk calculation

### Building the iOS App

1. Open the project in Xcode
2. Create a new Xcode project (iOS App, SwiftUI) in the repository root
3. Add the existing Swift files to the appropriate targets
4. Add the `VitaminDTrackerCore` package as a local dependency
5. Build and run on simulator or device

> **Note:** The `VitaminDTracker/` directory contains the SwiftUI app files. You'll need to create an Xcode project file (`.xcodeproj` or use Xcode's "Open in Xcode" for a Swift package) to build the full app.

### Running on Device

The app requires iOS 17.0 or later. To run on a physical device:
1. Set your development team in Xcode signing settings
2. Connect your iPhone
3. Build and run

---

## Analytics

The app uses a lightweight local analytics approach:

- **App Store Connect** is the primary source for download counts and install data
- **In-app tracking** records local event counts for:
  - App opens
  - Onboarding completions
  - Sun session starts and completions
  - Lab result entries
  - Supplement updates
- **No personal health data is collected remotely**
- **No third-party analytics SDKs** are included by default

To add remote analytics (e.g., TelemetryDeck, PostHog, or similar privacy-conscious providers), extend `AnalyticsService.swift`.

---

## Background Daily Updates

### Intended Behavior
The estimated vitamin D level should update at midnight Pacific Time each day, applying:
- Daily metabolic decay
- Daily supplement contribution

### iOS Implementation
iOS strictly limits background execution. The app uses:
- `BGAppRefreshTask` for best-effort scheduled background processing
- **Catch-up on app open**: When the app is launched, it computes all missed daily updates since the last known state

### Correctness Guarantee
Regardless of whether background tasks fire on time, the estimate is always correct when the app is opened. The catch-up mechanism replays all missing days from the last known anchor.

---

## Known Limitations

### Scientific Uncertainty
- The vitamin D estimation model is based on population-level research and simplified pharmacokinetic assumptions
- Individual variation in vitamin D metabolism is significant (body weight, age, skin pigmentation, genetics, health conditions)
- UV index estimation without real-time weather data is approximate
- The model does not account for dietary vitamin D, medication interactions, or malabsorption conditions
- D2 vs D3 effectiveness ratio (0.5) is a simplified approximation of a complex relationship
- Sun exposure production model uses simplified diminishing returns without skin-type-specific adjustments

### Background Execution Limits on iOS
- iOS does not guarantee exact midnight execution of background tasks
- `BGAppRefreshTask` firing depends on device usage patterns, battery state, and system heuristics
- The catch-up mechanism ensures correctness whenever the app is opened

### Analytics / Download Count Limitations
- Exact download counts are not available within the app itself
- Download and install data should be obtained from App Store Connect
- In-app analytics are local-only by default (no remote collection)
- DAU/MAU metrics require a remote analytics provider for accurate tracking

### Why This App Should Not Be Used as a Substitute for Medical Care
- Vitamin D levels affect bone health, immune function, and many other physiological processes
- Only a blood test (serum 25(OH)D) can accurately measure vitamin D status
- Supplementation needs vary dramatically by individual and health condition
- Excessive vitamin D supplementation can cause toxicity
- Sun exposure carries skin cancer risk that must be weighed against vitamin D benefits
- This app cannot account for individual health conditions, medications, or risk factors
- **Always consult a qualified healthcare provider** for vitamin D testing, interpretation, supplementation, and sun exposure guidance