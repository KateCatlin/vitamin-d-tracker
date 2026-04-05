import Foundation

/// UV risk level for sun exposure.
public enum UVRiskLevel: String, Sendable {
    case low = "Low"
    case moderate = "Moderate"
    case high = "High"
    case veryHigh = "Very High"
    case extreme = "Extreme"

    public var description: String {
        switch self {
        case .low: return "Low risk. Enjoy the outdoors!"
        case .moderate: return "Moderate risk. Seek shade during midday."
        case .high: return "High risk. Wear sunscreen and protective clothing."
        case .veryHigh: return "Very high risk. Minimize sun exposure 10am-4pm."
        case .extreme: return "Extreme risk. Avoid outdoor exposure if possible."
        }
    }

    public var shouldWarn: Bool {
        switch self {
        case .low, .moderate: return false
        case .high, .veryHigh, .extreme: return true
        }
    }
}

/// Calculates UV-related sun exposure risk and sunburn warnings.
///
/// Uses the Standard Erythemal Dose (SED) model to estimate when
/// cumulative UV exposure reaches the sunburn threshold.
///
/// See MODELING.md for scientific references.
public struct UVRiskCalculator {

    /// Classify UV risk level from a UV index value.
    public static func riskLevel(uvIndex: Double) -> UVRiskLevel {
        switch uvIndex {
        case ..<3: return .low
        case 3..<6: return .moderate
        case 6..<8: return .high
        case 8..<11: return .veryHigh
        default: return .extreme
        }
    }

    /// Calculate accumulated Standard Erythemal Dose (SED) for a session.
    ///
    /// - Parameters:
    ///   - uvIndex: Current UV index.
    ///   - durationMinutes: Duration of exposure in minutes.
    ///   - skinExposureFraction: Fraction of skin exposed (affects comfort but not burn risk per area).
    ///   - cloudCoverFraction: Cloud cover fraction.
    /// - Returns: Accumulated SED.
    public static func accumulatedSED(
        uvIndex: Double,
        durationMinutes: Double,
        cloudCoverFraction: Double = 0.0
    ) -> Double {
        let cloudFactor = 1.0 - 0.75 * min(max(cloudCoverFraction, 0.0), 1.0)
        let effectiveUVI = uvIndex * cloudFactor
        return effectiveUVI * ModelingAssumptions.sedPerMinutePerUVI * durationMinutes
    }

    /// Estimate the maximum recommended exposure time in minutes before sunburn risk.
    ///
    /// - Parameters:
    ///   - uvIndex: Current UV index.
    ///   - cloudCoverFraction: Cloud cover fraction.
    ///   - skinType: User's Fitzpatrick skin type (nil uses conservative default).
    ///   - sunburnThresholdSED: SED threshold override (ignored when skinType is provided).
    /// - Returns: Maximum recommended exposure in minutes. Returns nil if UV is negligible.
    public static func maxSafeExposureMinutes(
        uvIndex: Double,
        cloudCoverFraction: Double = 0.0,
        skinType: FitzpatrickSkinType? = nil,
        sunburnThresholdSED: Double? = nil
    ) -> Double? {
        let threshold = sunburnThresholdSED ?? ModelingAssumptions.sunburnThreshold(for: skinType)
        let cloudFactor = 1.0 - 0.75 * min(max(cloudCoverFraction, 0.0), 1.0)
        let effectiveUVI = uvIndex * cloudFactor

        guard effectiveUVI > 0 else { return nil }

        let sedPerMinute = effectiveUVI * ModelingAssumptions.sedPerMinutePerUVI
        return threshold / sedPerMinute
    }

    /// Check if the current exposure has exceeded the safe threshold.
    ///
    /// - Parameters:
    ///   - uvIndex: Current UV index.
    ///   - durationMinutes: Duration exposed.
    ///   - cloudCoverFraction: Cloud cover.
    ///   - skinType: User's Fitzpatrick skin type (nil uses conservative default).
    ///   - sunburnThresholdSED: SED threshold override (ignored when skinType is provided).
    /// - Returns: true if the user should be warned about overexposure.
    public static func isOverexposed(
        uvIndex: Double,
        durationMinutes: Double,
        cloudCoverFraction: Double = 0.0,
        skinType: FitzpatrickSkinType? = nil,
        sunburnThresholdSED: Double? = nil
    ) -> Bool {
        let threshold = sunburnThresholdSED ?? ModelingAssumptions.sunburnThreshold(for: skinType)
        let sed = accumulatedSED(
            uvIndex: uvIndex,
            durationMinutes: durationMinutes,
            cloudCoverFraction: cloudCoverFraction
        )
        return sed >= threshold
    }

    /// Calculate the percentage of safe exposure used.
    ///
    /// - Returns: Value from 0.0 to 1.0+ (over 1.0 means overexposed).
    public static func exposurePercentage(
        uvIndex: Double,
        durationMinutes: Double,
        cloudCoverFraction: Double = 0.0,
        skinType: FitzpatrickSkinType? = nil,
        sunburnThresholdSED: Double? = nil
    ) -> Double {
        let threshold = sunburnThresholdSED ?? ModelingAssumptions.sunburnThreshold(for: skinType)
        let sed = accumulatedSED(
            uvIndex: uvIndex,
            durationMinutes: durationMinutes,
            cloudCoverFraction: cloudCoverFraction
        )
        guard threshold > 0 else { return 0.0 }
        return sed / threshold
    }
}
