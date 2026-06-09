# Vitamin D Estimation Model — Scientific Documentation

## Overview

This document describes the scientific model used by the Vitamin D Tracker app to estimate a user's serum 25-hydroxyvitamin D (25(OH)D) level over time. The model combines:

1. Laboratory measurements (when available) as trusted anchor points
2. Geographic and seasonal baseline estimation
3. Daily metabolic decay of circulating vitamin D
4. Incremental effects of daily supplementation (D2 and D3)
5. Incremental effects of tracked sun exposure sessions
6. UV/sunburn risk estimation

**⚠️ This model provides rough estimates only. It is NOT medical advice and should not be used for diagnosis or treatment decisions.**

---

## 1. Measured vs. Estimated Values

The app clearly distinguishes between:

| Source | Description | Confidence |
|--------|-------------|------------|
| **Lab Measurement** | Direct blood test result (25(OH)D) | High |
| **Geographic Estimate** | Baseline estimated from location and season | Low |
| **Model Estimate** | Computed from anchor + decay + supplements + sun | Moderate (recent lab) or Low (no lab) |

A lab result is always the most trusted data point. When entered, it becomes the new anchor from which all future estimates are projected.

---

## 2. Units and Conversions

The app supports two common units for serum 25(OH)D:

- **ng/mL** (nanograms per milliliter) — common in the United States
- **nmol/L** (nanomoles per liter) — SI unit, common internationally

**Conversion factor:** 1 ng/mL = 2.496 nmol/L

All internal calculations use ng/mL. Values are converted to/from nmol/L at input and display boundaries.

**Source:** National Institutes of Health, Office of Dietary Supplements. Vitamin D Fact Sheet for Health Professionals.

---

## 3. Baseline Estimation (No Lab Data)

When no laboratory measurement is available, the app estimates a baseline 25(OH)D level using:

### 3.1 Default Baseline

The general population mean is approximately **25 ng/mL** (62.4 nmol/L) for US adults.

**Source:** Looker AC, et al. Serum 25-hydroxyvitamin D status of the US population: 1988-1994 compared with 2000-2004. *Am J Clin Nutr.* 2008;88(6):1519-1527.

### 3.2 Latitude Adjustment

Higher latitudes receive less UV-B radiation year-round, leading to lower average vitamin D levels.

**Model:**
```
adjustment = -0.333 × (|latitude| - 30°)
Clamped to [-12, +8] ng/mL
```

| Latitude | Adjustment |
|----------|-----------|
| 0° (equator) | +8 ng/mL (raw +9.99, capped by the +8 clamp) |
| 30° | 0 ng/mL |
| 45° | -5 ng/mL |
| 60° | -10 ng/mL |

Note: the raw formula yields +9.99 ng/mL at the equator, but the `[-12, +8]` clamp caps the applied value at +8 ng/mL.

**Sources:**
- Kimlin MG. Geographic location and vitamin D synthesis. *Mol Aspects Med.* 2008;29(6):453-461.
- Webb AR, Kline L, Holick MF. Influence of season and latitude on the cutaneous synthesis of vitamin D3. *J Clin Endocrinol Metab.* 1988;67(2):373-378.

### 3.3 Seasonal Adjustment

UV-B availability varies significantly by season, especially at higher latitudes.

**Model:** Cosine function with peak at summer solstice (~June 21 / Day 172 in Northern Hemisphere).

```
seasonal_effect = 8 × cos(2π × (day - peak_day) / 365.25) × latitude_scale
latitude_scale = min(|latitude| / 50, 1.0)
```

For the Southern Hemisphere, the peak shifts by ~183 days.

**Amplitude:** ±8 ng/mL at latitudes ≥50°, scaled down for lower latitudes.

**Source:** Klingberg E, et al. Seasonal variations in serum 25-hydroxy vitamin D levels in a Swedish cohort. *Endocrine.* 2015;49(3):800-808.

### 3.4 Fitzpatrick Skin-Type Adjustment to Baseline

The same `vitaminDProductionMultiplier` used for tracked sun sessions (§6.3) is applied to the **sun-derived portion** of the baseline. NHANES 2001-04 reports a non-Hispanic Black population mean of ~16 ng/mL versus ~26 ng/mL for non-Hispanic Whites — almost entirely an incidental-sun effect. Diet (~190 IU/day → ~2 ng/mL) is unaffected by melanin, so:

```
sun_portion = max(unadjusted_baseline − 2, 0)
baseline    = sun_portion × skin_type_multiplier + 2
```

With Type II (multiplier 1.0) or no skin type, this is a no-op.

### 3.5 Background Input (Diet + Incidental Sun)

**Why this term exists.** The supplement dose-response in §5.1 (~10 ng/mL per 1000 IU) is a *marginal* effect: Heaney 2003 measured the rise above each subject's existing baseline while they continued to live normally. Treating it as the *only* input — as the model originally did — converges everyone toward `dose / 100` ng/mL, as if they ate zero vitamin D and never went outside. NHANES 2001-04 puts the unsupplemented US mean at ~24 ng/mL, even though dietary intake (~190 IU/day, NHANES 2015-16) alone would only sustain ~2 ng/mL. The gap is incidental sun exposure no one ever logs.

**Model.** Each day receives a background gain that exactly cancels decay at the local baseline:

```
baseline_today  = estimateBaseline(location, today, skin_type)   // §3.1–3.4, re-evaluated per day
background_gain = baseline_today × daily_decay_rate
```

With no supplement and no tracked sun the level converges to `baseline_today`; the supplement effect (+10 ng/mL per 1000 IU D3) stacks additively on top. Tracked sun sessions encode *deliberate* exposure and are additive to the baseline's *incidental* exposure — there is no double-count.

---

## 4. Decay Model (Half-Life)

Circulating 25(OH)D follows approximately first-order elimination kinetics.

### 4.1 Half-Life

**Chosen value: 21 days**

The literature reports half-lives ranging from 15-25 days for 25(OH)D. We use 21 days as a central estimate.

**Sources:**
- Jones KS, et al. 25(OH)D2 half-life is shorter than 25(OH)D3 half-life and is influenced by DBP concentration and genotype. *J Clin Endocrinol Metab.* 2014;99(9):3373-3381.
- Heaney RP, et al. 25-Hydroxylation of vitamin D3: relation to circulating vitamin D3 under various input conditions. *Am J Clin Nutr.* 2008;87(6):1738-1742.

### 4.2 Daily Decay Rate

```
daily_decay_rate = 1 - 2^(-1/21) ≈ 0.0325 (3.25% per day)
```

Each day, the model applies:
```
new_level = old_level × (1 - daily_decay_rate)
```

### 4.3 Simplifications

- We use a single half-life for both D2 and D3 metabolites, though D2 may have a somewhat shorter half-life in practice.
- We do not model tissue storage, redistribution, or two-compartment kinetics.
- The model assumes linear decay without saturation effects.

---

## 5. Supplementation Effects

### 5.1 Dose-Response Relationship

At steady state, approximately **10 ng/mL increase per 1000 IU/day** of vitamin D3 supplementation.

This is a widely cited approximation, though individual response varies significantly based on body weight, baseline level, genetics, and other factors.

**Sources:**
- Heaney RP, et al. Human serum 25-hydroxycholecalciferol response to extended oral dosing with cholecalciferol. *Am J Clin Nutr.* 2003;77(1):204-210.
- Holick MF. Vitamin D deficiency. *N Engl J Med.* 2007;357(3):266-281.

### 5.2 Daily Incremental Model

Rather than modeling the full accumulation curve, we use a simplified daily increment that, at steady state, exactly balances daily decay:

```
daily_supplement_rise = (dose_IU / 1000) × 10 × daily_decay_rate
```

This produces the correct steady-state level while being simple to compute day-by-day.

> **Note:** "steady state" here is the *marginal* increment from the supplement alone. With the background term (§3.5) active, the model converges toward `baseline + (dose_IU / 100)`, not `dose_IU / 100` by itself.

### 5.3 Vitamin D2 vs D3 Effectiveness

**D3 (cholecalciferol)** is considered the reference standard (multiplier = 1.0).

**D2 (ergocalciferol)** is modeled as **50% as effective** as D3 for raising serum 25(OH)D (multiplier = 0.5).

This is a conservative estimate. Meta-analyses report D2 as roughly 30-70% less effective than D3, with considerable variability.

**Sources:**
- Tripkovic L, et al. Comparison of vitamin D2 and vitamin D3 supplementation in raising serum 25-hydroxyvitamin D status: a systematic review and meta-analysis. *Am J Clin Nutr.* 2012;95(6):1357-1364.
- Heaney RP, et al. Vitamin D3 is more potent than vitamin D2 in humans. *J Clin Endocrinol Metab.* 2011;96(3):E447-E452.

### 5.4 Forward-Only Changes

When the user changes their supplement dose, the new dose applies from that day forward only. Historical estimates are not retroactively recalculated. This preserves the integrity of past estimates and event records.

---

## 6. Sun Exposure Model

### 6.1 Vitamin D Production from Sunlight

UV-B radiation (280-315 nm) converts 7-dehydrocholesterol in the skin to previtamin D3. Production depends on:

- UV index (intensity of UV-B radiation)
- Fraction of skin exposed
- Cloud cover (which attenuates UV)
- Duration of exposure (with diminishing returns)
- **Fitzpatrick skin type** (melanin absorbs UV-B, reducing production in darker skin)

### 6.2 Base Production Rate

**Chosen value: 5.7 IU per minute at UV index 1, with full-body exposure and clear sky.**

This is derived from the well-documented observation that fair-skinned individuals produce approximately 1000 IU of vitamin D in 10-15 minutes of midday summer sun (UV index ~7) with ~25% skin exposed.

```
1000 IU = rate × 7 (UVI) × 0.25 (skin) × 10 min
rate ≈ 5.7 IU/min/UVI/full-body
```

**Sources:**
- Holick MF. Vitamin D: importance in the prevention of cancers, type 1 diabetes, heart disease, and osteoporosis. *Am J Clin Nutr.* 2004;79(3):362-371.
- Webb AR, Holick MF. The role of sunlight in the cutaneous production of vitamin D3. *Annu Rev Nutr.* 1988;8:375-399.

### 6.3 Fitzpatrick Skin Type Adjustment

Melanin in the skin absorbs UV-B radiation, reducing previtamin D3 synthesis. Individuals with darker skin require longer UV exposure to produce the same amount of vitamin D as individuals with lighter skin.

The Fitzpatrick scale classifies skin into six phototypes (I–VI). We apply a production multiplier relative to Type II (fair skin) as the reference:

| Fitzpatrick Type | Description | Vitamin D Multiplier | Sunburn Threshold (SED) |
|-----------------|-------------|---------------------|------------------------|
| Type I | Very fair, always burns | 1.20 | 2.0 |
| Type II | Fair, burns easily (reference) | 1.00 | 2.5 |
| Type III | Medium, tans gradually | 0.75 | 4.0 |
| Type IV | Olive, tans well | 0.55 | 5.0 |
| Type V | Brown, rarely burns | 0.35 | 8.0 |
| Type VI | Dark, never burns | 0.20 | 10.0 |

**Applied as:**
```
effective_production = base_production × skin_type_multiplier
```

**Sources:**
- Fitzpatrick TB. The validity and practicality of sun-reactive skin types I through VI. *Arch Dermatol.* 1988;124(6):869-871.
- Clemens TL, et al. Increased skin pigment reduces the capacity of skin to synthesise vitamin D3. *Lancet.* 1982;1(8263):74-76.

### 6.4 Cloud Cover Effect

Clouds reduce UV transmission approximately as:
```
effective_UV = UV_index × (1 - 0.75 × cloud_fraction)
```

- Clear sky: 100% transmission
- Full overcast: 25% transmission

**Source:** WHO. Global Solar UV Index: A Practical Guide. 2002.

### 6.5 Diminishing Returns

Prolonged UV exposure does not produce vitamin D indefinitely. After ~30 minutes at high UV, previtamin D3 is photodegraded to inactive isomers (lumisterol, tachysterol).

**Model:** Saturating exponential
```
time_constant = 300 / max(effective_UV, 0.5)
max_effective = time_constant × 1.5
effective_duration = max_effective × (1 - e^(-duration / time_constant))
```

At UV index 10: plateau around 30 minutes.
At UV index 3: plateau around 100 minutes.

**Source:** Holick MF. Vitamin D: importance in the prevention of cancers... *Am J Clin Nutr.* 2004.

### 6.6 IU to ng/mL Conversion (Acute Dose)

For a single sun exposure session:
```
ng_mL_gain = total_IU_produced / 1200
```

This approximation assumes that ~1200 IU of acutely produced vitamin D results in approximately 1 ng/mL increase in serum 25(OH)D. This is a rough estimate; the actual dose-response depends on many factors.

---

## 7. UV Risk and Sunburn Warning Model

### 7.1 Standard Erythemal Dose (SED)

One SED equals 100 J/m² of erythemally-weighted UV radiation. The minimal erythemal dose (MED) — the UV dose causing perceptible reddening — varies by skin type:

| Skin Type (Fitzpatrick) | MED (SED) |
|--------------------------|-----------|
| Type I (very fair) | ~2 SED |
| Type II (fair) | ~2.5 SED |
| Type III (medium) | ~4 SED |
| Type IV (olive) | ~5 SED |
| Type V (brown) | ~8 SED |
| Type VI (dark) | ~10 SED |

**Default threshold: 2.5 SED** (Fitzpatrick Type II). When the user's Fitzpatrick skin type is known, the app uses their type-specific threshold from the table above.

### 7.2 SED Accumulation Rate

```
SED_per_minute = UV_index × 0.015
```

This is derived from:
- At UV index N, erythemal irradiance ≈ N × 25 mW/m² = N × 0.025 W/m²
- SED per minute = UVI × 0.025 × 60 / 100 = UVI × 0.015

### 7.3 Maximum Safe Exposure Time

```
max_safe_minutes = threshold_SED / (effective_UVI × 0.015)
```

Example: At UV index 7 (clear sky), max safe time for fair skin ≈ 2.5 / (7 × 0.015) ≈ 24 minutes.

### 7.4 UV Risk Classification

| UV Index | Risk Level |
|----------|-----------|
| < 3 | Low |
| 3-5 | Moderate |
| 6-7 | High |
| 8-10 | Very High |
| 11+ | Extreme |

**Source:** WHO/WMO/UNEP/ICNIRP. Global Solar UV Index: A Practical Guide. World Health Organization, 2002.

---

## 8. Daily Update Process

Each day at midnight (Pacific Time, approximated), the model:

1. **Applies decay**: `level = level × (1 - 0.0325)`
2. **Applies background**: `level += baseline_today × 0.0325` (diet + incidental sun, see §3.5)
3. **Applies supplement**: `level += daily_supplement_rise`
4. **Adds sun gains**: `level += sum of session gains for that day`
5. **Records the event** with all component values

`baseline_today` is re-evaluated for the calendar date being processed, so a multi-day catch-up moves through the seasonal curve correctly.

### 8.1 Catch-Up on App Open

If the app has not run daily updates (e.g., the user hasn't opened the app for 5 days), it replays all missed days upon next open. This ensures the estimate is always current.

### 8.2 iOS Background Execution

The estimate is brought current entirely through the **catch-up on app open** mechanism described in §8.1 — when the app launches it replays every missed day from the last anchor, so the displayed level is always correct as of the moment you open the app. The app does **not** register an `BGAppRefreshTask`; no background execution is required for correctness, and the app requests no background-mode entitlements.

---

## 9. UV Index Estimation

The UV index that feeds §6 (sun exposure) and §7 (sunburn risk) is resolved by `UVIndexProvider` in the app target, which prefers a live source and degrades gracefully:

| Priority | Source | What it accounts for |
|---|---|---|
| 1 | WeatherKit `currentWeather.uvIndex` | Sun position, cloud, ozone column, aerosols, altitude — everything |
| 2 | Cached WeatherKit value (< 15 min old, ~1 km cell) | Same, slightly stale |
| 3 | `BaselineEstimator.estimateUVIndex` | Sun position only — clear-sky |

WeatherKit was chosen over third-party APIs because the SDK is native Swift, the 500k call/month tier is included with the paid Apple Developer Program (no API key to ship or proxy), and Apple handles the privacy disclosure. The app stays fully functional without it; the UI exposes `uvIndexSource` so the displayed value can be labelled "live" vs "estimate".

### 9.1 Clear-sky fallback model

The fallback computes the sun's instantaneous elevation from first principles — no network, no lookup tables, no device-timezone dependence.

**Solar declination** (Cooper's equation) — the latitude where the sun is directly overhead today, ranging ±23.45° across the year:

```
δ = 23.45° · sin(2π · (284 + dayOfYear) / 365)
```

**Hour angle** — how far the Earth has rotated since local solar noon, 15° per hour. The clock is read in UTC and longitude is folded in directly, so `Date()` is treated purely as an instant:

```
H = 15° · (utcHour − 12) + longitude
```

This is why solar noon in Cabo San Lucas (longitude −109.9°, ~5° west of the MST standard meridian) lands at ~12:20 PM on the wall clock rather than 12:00. The previous implementation hardcoded `solarNoon = 12.0` and missed this.

**Solar elevation** — the standard altitude formula, combining all three inputs:

```
sin(α) = sin(lat)·sin(δ) + cos(lat)·cos(δ)·cos(H)
```

**UV index** — empirical power law on the elevation:

```
UVI = 12 · sin(α)^2.5     (clamped to 0 when α ≤ 0)
```

`12` is the assumed peak when the sun is at zenith on a clear day at sea level with a typical ozone column. The `2.5` exponent approximates the slant-path optical air mass: at low sun angles, UV-B traverses far more atmosphere and ozone, and erythemal irradiance falls off much faster than `cos(zenith)` alone would predict. Madronich (1993) and the radiative-transfer literature support exponents in the 2.3–2.6 range for clear-sky erythemal UV.

### 9.2 Why the power law must apply to the *instantaneous* elevation

An earlier version of this model decomposed the calculation into `(noon-peak intensity) × (time-of-day factor)`:

```
UVI_old = 12 · sin(α_noon)^2.5 · cos((π/2)·hoursFromNoon/halfDayLength)     # WRONG
```

This gives correct answers at solar noon (where it was tested) but the daily curve has the wrong shape. The plain cosine on the time axis falls off far more gently than the real atmosphere.

Worked example — Cabo San Lucas (22.89° N), April 8, 7:30 AM MST:

| | Old model | New model | Reported |
|---|---|---|---|
| Sun elevation used | 73.9° (noon) | 18.7° (now) | — |
| `sin(elev)^2.5` | 0.90 | 0.057 | — |
| Time scaling | × cos(1.14) ≈ 0.41 | none (folded into elev) | — |
| **UV index** | **4.5** | **0.7** | **~1–2** |

The old model's morning shoulder was steep enough to cross the UV ≥ 3 vitamin-D threshold around 7:15 AM; the corrected model crosses it around 9 AM, which matches both the new shape and published Cabo forecasts. The regression test `testTropicalEarlyMorningUVIsLow` pins this.

### 9.3 Known approximations

- **Equation of time ignored.** Real solar noon drifts ±15 minutes through the year due to Earth's orbital eccentricity and axial tilt. Worst case in early November: ~16 minutes early. Effect on UV: a few percent at midday, larger near sunrise/sunset.
- **Day-of-year read in UTC.** Near local solar midnight this can be off by one calendar day, but declination changes < 0.4°/day so the error is negligible.
- **Constant zenith UVI of 12.** Real values range ~10–14 at sea level depending on ozone column and aerosols, and increase ~6% per km of altitude. The model has no altitude input.
- **No refraction.** The model puts the horizon at geometric `α = 0`. Atmospheric refraction lifts the visible sun ~0.6° at the horizon — irrelevant for UV, which is essentially zero at those angles anyway.

---

## 10. Confidence and Uncertainty

### What the model handles well:
- Directional trends (decay, supplementation, sun exposure)
- Relative comparisons (D2 vs D3, more sun = more vitamin D)
- Order-of-magnitude estimates

### Known sources of uncertainty:
- Individual variation in vitamin D metabolism (body weight, age, skin pigmentation, genetics)
- Simplified single-compartment pharmacokinetic model
- Clear-sky UV fallback is blind to cloud, ozone anomalies, aerosols, and altitude (only relevant when WeatherKit is unavailable)
- Background input is a population-level estimate of incidental sun (indoor workers, shift workers, and people who avoid the sun will be overestimated)
- No accounting for medications that affect vitamin D metabolism
- Fitzpatrick skin type multipliers are approximate population-level estimates
- No accounting for sunscreen use
- No accounting for altitude effects on UV

### What the model cannot do:
- Provide medically accurate vitamin D levels
- Replace laboratory blood testing
- Account for individual health conditions
- Diagnose or treat any condition

---

## 11. References

1. Holick MF. Vitamin D deficiency. *N Engl J Med.* 2007;357(3):266-281.
2. Heaney RP, et al. Human serum 25-hydroxycholecalciferol response to extended oral dosing with cholecalciferol. *Am J Clin Nutr.* 2003;77(1):204-210.
3. Tripkovic L, et al. Comparison of vitamin D2 and vitamin D3 supplementation in raising serum 25-hydroxyvitamin D status: a systematic review and meta-analysis. *Am J Clin Nutr.* 2012;95(6):1357-1364.
4. Jones KS, et al. 25(OH)D2 half-life is shorter than 25(OH)D3 half-life and is influenced by DBP concentration and genotype. *J Clin Endocrinol Metab.* 2014;99(9):3373-3381.
5. Webb AR, Kline L, Holick MF. Influence of season and latitude on the cutaneous synthesis of vitamin D3. *J Clin Endocrinol Metab.* 1988;67(2):373-378.
6. Kimlin MG. Geographic location and vitamin D synthesis. *Mol Aspects Med.* 2008;29(6):453-461.
7. WHO/WMO/UNEP/ICNIRP. Global Solar UV Index: A Practical Guide. World Health Organization, 2002.
8. Looker AC, et al. Serum 25-hydroxyvitamin D status of the US population. *Am J Clin Nutr.* 2008;88(6):1519-1527.
9. Holick MF. Vitamin D: importance in the prevention of cancers, type 1 diabetes, heart disease, and osteoporosis. *Am J Clin Nutr.* 2004;79(3):362-371.
10. Heaney RP, et al. Vitamin D3 is more potent than vitamin D2 in humans. *J Clin Endocrinol Metab.* 2011;96(3):E447-E452.
11. Klingberg E, et al. Seasonal variations in serum 25-hydroxy vitamin D levels in a Swedish cohort. *Endocrine.* 2015;49(3):800-808.
12. NIH Office of Dietary Supplements. Vitamin D Fact Sheet for Health Professionals. https://ods.od.nih.gov/factsheets/VitaminD-HealthProfessional/
13. Fitzpatrick TB. The validity and practicality of sun-reactive skin types I through VI. *Arch Dermatol.* 1988;124(6):869-871.
14. Clemens TL, et al. Increased skin pigment reduces the capacity of skin to synthesise vitamin D3. *Lancet.* 1982;1(8263):74-76.
15. Madronich S. The atmosphere and UV-B radiation at ground level. In: *Environmental UV Photobiology.* Springer, 1993. pp. 1–39.
16. Cooper PI. The absorption of radiation in solar stills. *Solar Energy.* 1969;12(3):333-346. (Solar declination approximation.)
