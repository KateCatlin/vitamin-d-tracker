# ☀️ Vitamin D Tracker

A native iPhone app that helps you estimate your current vitamin D level over time using lab results, daily supplementation, geographic and seasonal baselines, Fitzpatrick skin type, and tracked sun exposure sessions.

> **⚠️ Disclaimer:** This app provides estimates only. It is **not medical advice** and should not be used for diagnosis or treatment. Please consult a healthcare professional for interpretation of vitamin D levels, supplementation, and sun exposure guidance.

---

## Features

- **Onboarding flow** — City selection → Fitzpatrick skin type → optional lab result → supplement dose & type (D2/D3) → medical disclaimer
- **Dashboard** — Current estimated vitamin D level with source badge (Lab / Estimated), confidence indicator, baseline level, and supplement summary
- **Sun session tracking** — Live timer with real-time vitamin D gain adjusted for skin type, UV risk indicator, and skin-type-aware overexposure alerts
- **Settings** — Update Fitzpatrick skin type, enter new lab results, change supplement dose/type, and view model assumptions
- **Daily background updates** — Automatic decay and supplementation modeling with catch-up logic if background tasks are missed
- **Beautiful design** — Light, bright, minimal UI with soft cards, rounded corners, and a sunlight-inspired yellow & sky-blue palette

## Estimation Model

The core vitamin D estimation model includes:

| Component | Approach |
|---|---|
| **Decay** | First-order kinetics with a 21-day half-life (~3.25%/day loss) |
| **Supplementation** | ~10 ng/mL per 1,000 IU/day D3 at steady state; D2 at 50% effectiveness |
| **Sun exposure** | UV index × skin fraction × cloud attenuation × Fitzpatrick multiplier × saturating-exponential duration |
| **Fitzpatrick skin type (I–VI)** | Adjusts vitamin D production rate (1.2× for Type I down to 0.2× for Type VI) and sunburn SED thresholds |
| **Sunburn risk** | Standard Erythemal Dose (SED) accumulation with skin-type-specific thresholds |
| **Baseline estimation** | Latitude adjustment + cosine seasonal model when no lab data is available |
| **Lab anchoring** | New lab results become trusted anchors that reset projection baselines |

For full equations, constants, simplifications, confidence limitations, and 14 scientific references, see [**MODELING.md**](MODELING.md).

## Project Structure

```
vitamin-d-tracker/
├── Sources/VitaminDTrackerCore/    # Core estimation model (standalone SPM library)
├── VitaminDTracker/                # SwiftUI iPhone app
│   ├── Views/                      # Onboarding, Dashboard, Sun Session, Settings
│   ├── ViewModels/                 # MVVM ObservableObject view models
│   └── ...
├── Tests/                          # 101+ unit tests
├── MODELING.md                     # Scientific model documentation
└── README.md
```

### Architecture

- **Swift + SwiftUI** — Modern native Apple stack
- **MVVM** — `ObservableObject` view models with clear separation of concerns
- **SPM library** — Business logic lives in `VitaminDTrackerCore`, testable on Linux without Xcode
- **Local persistence** — `UserDefaults` + `Codable` JSON; no accounts, no cloud sync
- **Forward-only history** — Supplement changes apply from the date changed; historical estimates are never rewritten

## Getting Started

### Prerequisites

- **macOS** 14.0 or later
- **Xcode** 15.0 or later
- An Apple Developer account (for running on a physical device)

### Setup

1. **Clone the repository:**

   ```bash
   git clone https://github.com/KateCatlin/vitamin-d-tracker.git
   cd vitamin-d-tracker
   ```

2. **Open in Xcode:**

   ```bash
   open VitaminDTracker.xcodeproj
   ```

   Or if the project uses Swift Package Manager:

   ```bash
   open Package.swift
   ```

3. **Select a simulator or device** in Xcode's toolbar (iPhone recommended).

4. **Build and run** with `⌘R`.

### Running Tests

Run the full test suite from the command line:

```bash
swift test
```

Or use `⌘U` in Xcode. The suite includes 101+ tests covering decay half-life correctness, D2/D3 differential behavior, forward-only supplement changes, multi-day catch-up idempotency, sun exposure diminishing returns, SED overexposure thresholds, unit conversions (ng/mL ↔ nmol/L), baseline latitude/seasonal effects, and Fitzpatrick skin type modeling.

## Background Daily Updates

### Intended Behavior
The estimated vitamin D level updates at midnight each day, applying:
- Daily metabolic decay
- Daily supplement contribution

### iOS Implementation
iOS strictly limits background execution. The app uses:
- `BGAppRefreshTask` for best-effort scheduled background processing
- **Catch-up on app open**: When the app is launched, it computes all missed daily updates since the last known state

### Correctness Guarantee
Regardless of whether background tasks fire on time, the estimate is always correct when the app is opened. The catch-up mechanism replays all missing days from the last known anchor.

## Analytics

The app uses a lightweight local analytics approach:

- **App Store Connect** is the primary source for download counts and install data
- **In-app tracking** records local event counts for app opens, onboarding completions, sun session starts/completions, lab result entries, and supplement updates
- **No personal health data is collected remotely**
- **No third-party analytics SDKs** are included by default

To add remote analytics (e.g., TelemetryDeck, PostHog, or similar privacy-conscious providers), extend `AnalyticsService.swift`.

## Known Limitations

- **Scientific uncertainty** — The estimation model uses simplified first-order kinetics and population-average constants. Individual vitamin D metabolism varies significantly based on genetics, body composition, diet, and other factors not captured here.
- **iOS background scheduling** — True midnight-exact background execution is not guaranteed by iOS. The app uses `BGAppRefreshTask` as the best available approximation and replays missed updates on next launch.
- **Analytics gaps** — Exact download counts are only available via App Store Connect, not within the app itself. In-app analytics are lightweight and privacy-conscious.
- **Not medical advice** — This app is for personal wellness estimation only. It should never be used as a substitute for professional medical care, vitamin D testing, or supplementation guidance from a qualified healthcare provider.

## Contributing

Contributions are welcome! Whether it's improving the estimation model, enhancing the UI, fixing bugs, or improving documentation — all help is appreciated.

### How to Contribute

1. **Fork the repository** — Click the "Fork" button at the top of this page.

2. **Create a feature branch:**

   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make your changes** — Write clear, well-documented code. If you're modifying the estimation model, please update [MODELING.md](MODELING.md) with any new assumptions, equations, or references.

4. **Add or update tests** — All model changes should include corresponding test coverage. Run `swift test` to verify everything passes.

5. **Commit with a descriptive message:**

   ```bash
   git commit -m "Add: brief description of your change"
   ```

6. **Push to your fork and open a Pull Request:**

   ```bash
   git push origin feature/your-feature-name
   ```

   Then open a PR against the `main` branch of this repository.

### Contribution Ideas

- 🔬 **Model improvements** — Better decay curves, additional factors (e.g., BMI, age), improved sun exposure modeling
- 🌍 **Localization** — Translate the app into other languages
- ♿ **Accessibility** — VoiceOver improvements, Dynamic Type support
- 🎨 **UI/UX** — Animations, charts, historical vitamin D level graphs
- 📖 **Documentation** — Clarify scientific references, add diagrams, improve setup instructions
- 🐛 **Bug fixes** — See the [Issues](https://github.com/KateCatlin/vitamin-d-tracker/issues) tab

### Guidelines

- Please keep PRs focused — one feature or fix per PR.
- Follow the existing code style (Swift conventions, MVVM architecture).
- Be respectful and constructive in discussions.
- If you're adding scientific modeling changes, cite reputable sources (systematic reviews, public health bodies, peer-reviewed research).

## License

This project is licensed under the [MIT License](LICENSE).

---

Built with ☀️ by [@KateCatlin](https://github.com/KateCatlin)
