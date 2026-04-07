import Foundation

/// Documents the scientific assumptions and constants used in the vitamin D model.
/// See MODELING.md for detailed scientific references.
public struct ModelingAssumptions: Codable, Sendable {

    // MARK: - Half-life and Decay

    /// Approximate half-life of circulating 25(OH)D in days.
    /// Literature range: 15-25 days. We use 21 days as a central estimate.
    /// Source: Jones KS et al., 2014; Heaney et al., 2009
    public static let halfLifeDays: Double = 21.0

    /// Daily decay rate derived from half-life.
    /// decay = 1 - 2^(-1/halfLife)
    public static var dailyDecayRate: Double {
        1.0 - pow(2.0, -1.0 / halfLifeDays)
    }

    // MARK: - Supplementation

    /// Approximate increase in serum 25(OH)D per 1000 IU/day of D3 supplementation.
    /// Literature suggests ~10 ng/mL increase per 1000 IU/day at steady state.
    /// This varies with baseline, body weight, and other factors.
    /// We model daily incremental effect proportionally.
    /// Source: Heaney et al., 2003; Holick, 2007
    public static let steadyStateRisePerThousandIU: Double = 10.0 // ng/mL per 1000 IU/day

    /// Daily incremental rise from supplementation is modeled as:
    /// dailyRise = (doseIU / 1000) * steadyStateRisePerThousandIU * dailyDecayRate
    /// This represents the daily "refill" that, at steady state, exactly offsets decay.
    public static func dailySupplementRise(doseIU: Double, vitaminDType: VitaminDType) -> Double {
        let effectiveDose = doseIU * vitaminDType.effectivenessMultiplier
        return (effectiveDose / 1000.0) * steadyStateRisePerThousandIU * dailyDecayRate
    }

    // MARK: - Sun Exposure

    /// Minimum UV index required for meaningful vitamin D synthesis.
    /// At UVI below 3, UVB radiation is insufficient for the skin to
    /// produce vitamin D. Widely supported by dermatological research.
    /// Sources: Examine.com, GrassrootsHealth, CircadianSync
    public static let minimumUVIndexForVitaminD: Double = 3.0

    /// Base vitamin D production rate in IU per minute of full-body exposure
    /// at UV index 1, with clear sky.
    /// At UV index ~7 with ~25% skin exposed, fair-skinned individuals produce
    /// roughly 1000 IU in 10-15 minutes. We derive our constant from this.
    /// Source: Holick, 2007; Webb & Holick, 1988
    public static let baseIUPerMinuteAtUVI1: Double = 5.7

    /// Convert IU produced from sun exposure to approximate ng/mL change.
    /// A single dose response is roughly 1 ng/mL per 1000-1500 IU acute dose.
    /// We use 1 ng/mL per 1200 IU as a middle estimate.
    public static let iuPerNgMLAcuteDose: Double = 1200.0

    /// Maximum useful UV exposure duration factor.
    /// After ~30 minutes of high UV exposure, vitamin D production plateaus
    /// due to photodegradation of previtamin D3.
    /// Source: Holick, 2004
    public static let maxEffectiveMinutesHighUV: Double = 30.0

    // MARK: - Baseline Estimation

    /// Default baseline vitamin D level if no lab test is available.
    /// The average American adult has ~25 ng/mL.
    /// This is adjusted by latitude and season in the BaselineEstimator.
    public static let defaultBaselineNgML: Double = 25.0

    // MARK: - UV Risk

    /// Standard Erythemal Dose (SED) values for sunburn threshold.
    /// Fair skin (Fitzpatrick type I-II): ~2-3 SED to minimal erythema
    /// Medium skin (type III-IV): ~4-5 SED
    /// Dark skin (type V-VI): ~8-10 SED
    /// We default to a conservative 2.5 SED for safety warnings (Fitzpatrick type II).
    /// When a Fitzpatrick type is known, use its specific threshold instead.
    public static let defaultSunburnThresholdSED: Double = 2.5

    /// Returns the sunburn threshold for a given Fitzpatrick skin type,
    /// or the conservative default if skin type is unknown.
    public static func sunburnThreshold(for skinType: FitzpatrickSkinType?) -> Double {
        skinType?.sunburnThresholdSED ?? defaultSunburnThresholdSED
    }

    /// Returns the vitamin D production multiplier for a given Fitzpatrick skin type,
    /// or 1.0 (fair skin reference) if skin type is unknown.
    public static func vitaminDProductionMultiplier(for skinType: FitzpatrickSkinType?) -> Double {
        skinType?.vitaminDProductionMultiplier ?? 1.0
    }

    /// One SED = 100 J/m² of erythemally weighted UV.
    /// At UV index N, erythemal irradiance ≈ N × 25 mW/m² = N × 0.025 W/m².
    /// SED accumulation per minute ≈ UVI × 0.025 × 60 / 100 = UVI × 0.015
    public static let sedPerMinutePerUVI: Double = 0.015

    // MARK: - Display

    /// Human-readable summary of the model.
    public static var summary: String {
        """
        Vitamin D Estimation Model Summary
        ===================================
        • Half-life of 25(OH)D: \(halfLifeDays) days
        • Daily decay rate: \(String(format: "%.4f", dailyDecayRate)) (\(String(format: "%.1f", dailyDecayRate * 100))%)
        • Supplement effect: ~\(Int(steadyStateRisePerThousandIU)) ng/mL rise per 1000 IU/day D3 at steady state
        • D2 effectiveness: 50% of D3
        • Sun production: ~\(String(format: "%.1f", baseIUPerMinuteAtUVI1)) IU/min at UVI 1 (full body, clear sky)
        • Sunburn warning: skin-type-specific SED thresholds (Fitzpatrick I–VI)
        • Default sunburn threshold: \(defaultSunburnThresholdSED) SED (type II / fair skin)
        • Vitamin D production: adjusted by Fitzpatrick skin type (melanin absorption)
        • Default baseline (no lab data): \(Int(defaultBaselineNgML)) ng/mL, adjusted by latitude/season

        ⚠️ This model provides rough estimates only. It is NOT medical advice.
        Consult a healthcare provider for vitamin D testing and supplementation guidance.
        """
    }
}
