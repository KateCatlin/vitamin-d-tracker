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

## How the Estimate Is Calculated

Every midnight (or on the next app open if the phone slept through it), the model runs one update per missed day:

```
new_level = current_level − decay + background + supplement + tracked_sun
```

Each term has a single line of arithmetic and a paper behind it.

### 1. Decay — `current_level × 0.0325`

Circulating 25(OH)D follows first-order elimination with a **21-day half-life**, giving a daily decay rate of `1 − 2^(−1/21) ≈ 3.25%`. The literature reports 15–25 days; 21 is a central value.

> [Jones et al. 2014, *J Clin Endocrinol Metab*](https://pubmed.ncbi.nlm.nih.gov/24885631/) — measured 25(OH)D₃ half-life directly with stable-isotope tracers.

### 2. Background — `baseline_today × 0.0325`

Diet and incidental everyday sun (walking to the car, errands) keep an unsupplemented person near a baseline that depends on **city, season, and skin type** — not zero. NHANES puts the unsupplemented US mean at ~24 ng/mL even though dietary intake (~190 IU/day) alone would only sustain ~2 ng/mL; the gap is incidental sun no one ever logs.

This term is sized so that with no supplement and no tracked sun, the model holds steady at whatever `BaselineEstimator` predicts for that location and date — re-evaluated every day, so it drifts down through your city's winter and back up through summer.

> [NIH Office of Dietary Supplements, Vitamin D Fact Sheet](https://ods.od.nih.gov/factsheets/VitaminD-HealthProfessional/) — *"serum 25(OH)D levels are usually higher than would be predicted on the basis of vitamin D dietary intakes alone"*  
> [Looker et al. 2008, *Am J Clin Nutr*](https://pubmed.ncbi.nlm.nih.gov/19064511/) — NHANES population means (~24 ng/mL overall, ~10 ng/mL Black/White gap)  
> [Klingberg et al. 2015, *Endocrine*](https://pubmed.ncbi.nlm.nih.gov/25681052/) — seasonal swing amplitude  
> [Webb, Kline & Holick 1988, *J Clin Endocrinol Metab*](https://pubmed.ncbi.nlm.nih.gov/2839537/) — latitude cutoff for winter cutaneous synthesis  
> [Clemens et al. 1982, *Lancet*](https://pubmed.ncbi.nlm.nih.gov/6119494/) — melanin attenuation of vitamin D synthesis

### 3. Supplement — `(dose_IU / 1000) × 10 × 0.0325`

About **+10 ng/mL per 1,000 IU/day of D3** at steady state, applied as a daily increment. **D2** is modelled at **50% effectiveness**.

This is a *marginal* effect — the rise *above* baseline — which is why the background term above is needed. Without it, the model drifts toward `dose / 100` ng/mL as if you lived in a dark box.

> [Heaney et al. 2003, *Am J Clin Nutr*](https://pubmed.ncbi.nlm.nih.gov/12499343/) — established the ~10 ng/mL per 1,000 IU dose-response  
> [Tripkovic et al. 2012, *Am J Clin Nutr*](https://pubmed.ncbi.nlm.nih.gov/22552031/) — meta-analysis: D3 raises 25(OH)D more effectively than D2

### 4. Tracked sun sessions — `IU_produced / 1200`

For deliberately logged sessions: `UV index × skin fraction × cloud attenuation × Fitzpatrick multiplier`, run through a saturating-exponential duration curve (production plateaus after ~30 min at high UV as previtamin D₃ photodegrades). **No vitamin D is credited at UV index < 3.**

> [Holick 2007, *N Engl J Med*](https://pubmed.ncbi.nlm.nih.gov/17634462/) — production rates under realistic conditions  
> [Holick 2004, *Am J Clin Nutr*](https://pubmed.ncbi.nlm.nih.gov/14985208/) — previtamin D₃ photodegradation plateau  
> [WHO Global Solar UV Index, 2002](https://www.who.int/publications/i/item/9241590076) — UV index scale, cloud transmission, SED definitions

#### Where the UV index comes from

**WeatherKit when available, astronomy when not.** The app asks Apple's WeatherKit for the live `currentWeather.uvIndex` (cached 15 min per ~1 km cell to stay well under the 500k/month free tier). If that fails — offline, no entitlement, service hiccup — it falls through to a self-contained clear-sky model that needs nothing but the clock and your coordinates:

```
sin(elevation) = sin(lat)·sin(δ) + cos(lat)·cos(δ)·cos(hourAngle)
UVI            = 12 · sin(elevation)^2.5     (0 if sun below horizon)
```

where `δ` is the solar declination for the day of year and `hourAngle = 15°·(UTC_hour − 12) + longitude`. Reading the clock in UTC and folding longitude into the hour angle makes the result independent of the device's timezone — `Date()` is just an instant.

The `^2.5` exponent is the empirical bit: it approximates how much extra ozone column UV-B has to punch through at low sun angles. Earlier versions of this app applied that exponent only to the *noon* elevation and then scaled by a gentle `cos(t)` for time of day; that curve is far too generous in the morning (it put Cabo San Lucas at UV ~5 at 7:30 AM when the real number was ~1). Applying the power law to the *instantaneous* elevation fixes the shape — see `testTropicalEarlyMorningUVIsLow` for the regression.

> [Madronich 1993, *Environmental UV Photobiology*](https://link.springer.com/chapter/10.1007/978-1-4899-2406-3_1) — air-mass dependence of erythemal irradiance; basis for the `sin^p` power-law approximation  
> [NOAA Solar Calculator](https://gml.noaa.gov/grad/solcalc/) — reference for the solar position equations

### 5. Lab results override everything

A blood test becomes a trusted anchor: the model resets to that value on the test date and replays steps 1–4 forward to today.

For full equations, simplifying assumptions, confidence limitations, and the complete reference list, see [**MODELING.md**](MODELING.md).

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

5. **(Optional) Enable WeatherKit** for live UV index readings. In the Apple Developer portal, enable the **WeatherKit** capability for your App ID, then add the `com.apple.developer.weatherkit` entitlement to the app target in Xcode (Signing & Capabilities → + Capability → WeatherKit). Without this the app silently falls back to the offline clear-sky model — fully functional, just blind to today's actual cloud cover.

### Running Tests

Run the full test suite from the command line:

```bash
swift test
```

Or use `⌘U` in Xcode. The suite includes 140+ tests covering decay half-life correctness, D2/D3 differential behavior, forward-only supplement changes, multi-day catch-up idempotency, background-input convergence, sun exposure diminishing returns, SED overexposure thresholds, unit conversions (ng/mL ↔ nmol/L), baseline latitude/seasonal/skin-type effects, and Fitzpatrick skin type modeling.

## Background Daily Updates

### Intended Behavior
The estimated vitamin D level updates at midnight each day, applying:
- Daily metabolic decay
- Background input (diet + incidental sun, season-aware)
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

### Modeling assumptions that affect accuracy

The estimate is built from population-average science and a number of deliberate simplifications. None of these make the app unusable, but each is a place where your real level may diverge from the number shown. They are listed roughly in order of how much they could shift an individual's estimate, and we'd rather be upfront about them than imply more precision than the model has.

1. **The starting baseline is a population estimate.** Without a lab result, your anchor is a population average adjusted for city, season, and skin type. Real individual levels vary widely around that average, so the starting point alone can be off by a large margin until you enter a blood test.
2. **Supplement response is treated as linear.** The model adds about 10 ng/mL per 1,000 IU/day regardless of your current level or body weight. In reality the response is larger when you are deficient and smaller when you are already replete or have a higher BMI.
3. **Sun production relies on average conversion constants.** Turning UV exposure into a vitamin D figure multiplies several population-average constants together, so the absolute amount credited for a sun session is one of the rougher numbers in the app.
4. **UV is held constant during a logged sun session.** A session uses the UV index sampled when it starts and applies it for the whole duration. Long sessions, or sessions in the early morning or late afternoon when the sun's angle is changing quickly, may be over- or under-credited.
5. **A single 21-day half-life is used for everyone.** The published range is 15-25 days and varies between individuals, which affects how quickly levels fall and how fast supplements take effect.
6. **The "background" diet-and-incidental-sun term is a modeling construct.** It is tuned so an untracked person settles at their estimated baseline rather than decaying toward zero. It is internally consistent but inherits whatever error is in the baseline estimate (#1).
7. **Incidental sun may be counted twice.** The baseline already assumes some everyday sun. Someone in a sunny climate who also logs many sessions could have a little of that exposure double-counted.
8. **Cloud cover and exposed-skin fraction are rough inputs.** Both are simple, user-estimated factors applied linearly, so casual estimates flow straight into the result.
9. **No upper limit is applied.** Levels cannot go below zero, but there is no saturation ceiling, so an extreme combination of high dose plus heavy sun could produce an unrealistically high number.
10. **D2 is modeled only as weaker D3.** It is credited at 50% potency but uses the same decay as D3, even though D2 actually clears from the body differently.
11. **Lab results are treated as exact.** A blood test resets the estimate to its measured value without accounting for the normal variation between labs and assay methods (commonly around 10-15%).
12. **Seasonal changes lag reality slightly.** Because the level is pulled toward each day's baseline through a multi-week half-life, the modeled seasonal high and low can trail the actual change in sunlight by a few weeks.

### Operational limitations

- **Clear-sky UV fallback** — When WeatherKit is unavailable (offline, or the entitlement isn't configured), UV index comes from an astronomical model that's correct for sun *position* but blind to cloud cover, ozone anomalies, aerosols, and altitude. A clear-sky model in Seattle in June will say UV 8 while it's drizzling.
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
