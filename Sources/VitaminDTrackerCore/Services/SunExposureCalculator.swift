import Foundation

/// Calculates estimated vitamin D production from sun exposure sessions.
///
/// The model considers:
/// - UV index
/// - Exposed skin fraction
/// - Cloud cover
/// - Duration (with diminishing returns after ~30 min at high UV)
/// - Fitzpatrick skin type (melanin reduces UV-B absorption)
///
/// See MODELING.md for scientific references and methodology.
public struct SunExposureCalculator {

    /// Calculate estimated vitamin D production from a sun exposure session.
    ///
    /// - Parameters:
    ///   - uvIndex: Current UV index at the location.
    ///   - skinExposureFraction: Fraction of body surface area exposed (0.0-1.0).
    ///   - cloudCoverFraction: Cloud cover fraction (0.0 = clear, 1.0 = overcast).
    ///   - durationMinutes: Duration of exposure in minutes.
    ///   - skinType: User's Fitzpatrick skin type (nil uses fair-skin reference).
    /// - Returns: Estimated vitamin D production in ng/mL equivalent.
    public static func estimateVitaminDGain(
        uvIndex: Double,
        skinExposureFraction: Double,
        cloudCoverFraction: Double,
        durationMinutes: Double,
        skinType: FitzpatrickSkinType? = nil
    ) -> Double {
        guard uvIndex > 0, skinExposureFraction > 0, durationMinutes > 0 else {
            return 0.0
        }

        // Cloud cover reduces effective UV
        // Thin clouds: ~75% transmission, thick overcast: ~25%
        // Linear model: effective UV = UV * (1 - 0.75 * cloudCover)
        let cloudFactor = 1.0 - 0.75 * min(max(cloudCoverFraction, 0.0), 1.0)

        let effectiveUV = uvIndex * cloudFactor

        // Base production rate in IU/minute
        let baseRate = ModelingAssumptions.baseIUPerMinuteAtUVI1

        // Fitzpatrick skin type multiplier — darker skin produces less vitamin D
        let skinTypeMultiplier = ModelingAssumptions.vitaminDProductionMultiplier(for: skinType)

        // Production rate scales with UV index, skin exposure, and skin type
        let productionRateIUPerMin = baseRate * effectiveUV * min(max(skinExposureFraction, 0.0), 1.0) * skinTypeMultiplier

        // Apply diminishing returns for long sessions
        // Production plateaus after ~30 min at high UV due to previtamin D3 photodegradation
        let effectiveDuration = effectiveDurationMinutes(
            durationMinutes: durationMinutes,
            uvIndex: effectiveUV
        )

        // Total IU produced
        let totalIU = productionRateIUPerMin * effectiveDuration

        // Convert IU to ng/mL change
        let ngMLGain = totalIU / ModelingAssumptions.iuPerNgMLAcuteDose

        return max(ngMLGain, 0.0)
    }

    /// Calculate effective duration accounting for diminishing returns.
    ///
    /// At high UV, vitamin D production plateaus after ~30 minutes because
    /// previtamin D3 is photodegraded to inactive isomers.
    /// At lower UV, this takes longer to reach.
    ///
    /// Model: effective time = maxEffective * (1 - exp(-duration / timeConstant))
    /// where timeConstant scales inversely with UV.
    static func effectiveDurationMinutes(
        durationMinutes: Double,
        uvIndex: Double
    ) -> Double {
        guard uvIndex > 0 else { return 0.0 }

        // Time constant: at UVI 10, plateau reached around 30 min
        // At UVI 3, plateau reached around 100 min
        let timeConstant = ModelingAssumptions.maxEffectiveMinutesHighUV * 10.0 / max(uvIndex, 0.5)

        // Saturating exponential
        let maxEffective = timeConstant * 1.5
        let effective = maxEffective * (1.0 - exp(-durationMinutes / timeConstant))

        return effective
    }

    /// Estimate real-time vitamin D gain rate in ng/mL per minute.
    ///
    /// - Parameters:
    ///   - uvIndex: Current UV index.
    ///   - skinExposureFraction: Fraction of skin exposed.
    ///   - cloudCoverFraction: Cloud cover fraction.
    ///   - elapsedMinutes: Minutes already spent in the sun.
    ///   - skinType: User's Fitzpatrick skin type (nil uses fair-skin reference).
    /// - Returns: Estimated gain rate in ng/mL per minute.
    public static func currentGainRate(
        uvIndex: Double,
        skinExposureFraction: Double,
        cloudCoverFraction: Double,
        elapsedMinutes: Double,
        skinType: FitzpatrickSkinType? = nil
    ) -> Double {
        // Get gain at current time and 1 minute later
        let gainNow = estimateVitaminDGain(
            uvIndex: uvIndex,
            skinExposureFraction: skinExposureFraction,
            cloudCoverFraction: cloudCoverFraction,
            durationMinutes: elapsedMinutes,
            skinType: skinType
        )
        let gainNext = estimateVitaminDGain(
            uvIndex: uvIndex,
            skinExposureFraction: skinExposureFraction,
            cloudCoverFraction: cloudCoverFraction,
            durationMinutes: elapsedMinutes + 1.0,
            skinType: skinType
        )
        return gainNext - gainNow
    }
}
