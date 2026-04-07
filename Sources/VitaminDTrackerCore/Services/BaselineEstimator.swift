import Foundation

/// Estimates a baseline vitamin D level when no lab test is available.
/// Uses latitude and time of year as the primary factors.
///
/// The approach:
/// - Higher latitudes → lower baseline (less UV available year-round)
/// - Winter months → lower baseline (reduced solar angle)
/// - Summer months → higher baseline (more UV)
/// - Southern hemisphere seasons are flipped
///
/// See MODELING.md for detailed methodology and sources.
public struct BaselineEstimator {

    /// Estimate baseline vitamin D level in ng/mL from location and date.
    ///
    /// - Parameters:
    ///   - location: The user's home location.
    ///   - date: The date for the estimate (to account for seasonality).
    /// - Returns: Estimated 25(OH)D level in ng/mL.
    public static func estimateBaseline(
        location: HomeLocation,
        date: Date = Date()
    ) -> Double {
        let latitudeAdjustment = latitudeEffect(latitude: location.latitude)
        let seasonalAdjustment = seasonalEffect(latitude: location.latitude, date: date)

        let baseline = ModelingAssumptions.defaultBaselineNgML
            + latitudeAdjustment
            + seasonalAdjustment

        // Clamp to reasonable range (5 - 60 ng/mL for baseline estimates)
        return min(max(baseline, 5.0), 60.0)
    }

    /// Latitude effect on baseline vitamin D.
    /// At the equator (lat 0): +5 ng/mL
    /// At 30°: 0 ng/mL (no adjustment)
    /// At 45°: -5 ng/mL
    /// At 60°: -10 ng/mL
    ///
    /// Linear model: adjustment = -0.333 * (|latitude| - 30)
    /// Clamped to [-12, +8]
    static func latitudeEffect(latitude: Double) -> Double {
        let absLat = abs(latitude)
        let adjustment = -0.333 * (absLat - 30.0)
        return min(max(adjustment, -12.0), 8.0)
    }

    /// Seasonal effect on baseline vitamin D.
    /// Models seasonal UV availability using a cosine function.
    /// Peak in summer (~+8 ng/mL), trough in winter (~-8 ng/mL).
    /// Adjusted for hemisphere.
    static func seasonalEffect(latitude: Double, date: Date) -> Double {
        let calendar = Calendar(identifier: .gregorian)
        let dayOfYear = Double(calendar.ordinality(of: .day, in: .year, for: date) ?? 1)
        let daysInYear = 365.25

        // Peak UV is around summer solstice (day ~172 in Northern Hemisphere)
        // For Southern Hemisphere, shift by half a year
        let peakDay: Double = latitude >= 0 ? 172.0 : 172.0 + 182.5

        // Cosine function peaks at 0, so shift to peak at summer solstice
        let phase = 2.0 * Double.pi * (dayOfYear - peakDay) / daysInYear
        let seasonalAmplitude = 8.0

        // Scale amplitude by latitude — stronger seasonal swing at higher latitudes
        let latitudeScale = min(abs(latitude) / 50.0, 1.0)

        return seasonalAmplitude * cos(phase) * latitudeScale
    }

    /// Estimate UV index for a location and date/time.
    /// This is a rough model based on latitude, day of year, and time of day.
    /// In a production app, this would be supplemented by weather API data.
    ///
    /// - Parameters:
    ///   - location: Geographic location.
    ///   - date: Date and time.
    /// - Returns: Estimated UV index.
    public static func estimateUVIndex(
        location: HomeLocation,
        date: Date = Date()
    ) -> Double {
        let calendar = Calendar(identifier: .gregorian)
        let dayOfYear = Double(calendar.ordinality(of: .day, in: .year, for: date) ?? 1)
        let hour = Double(calendar.component(.hour, from: date))
        let minute = Double(calendar.component(.minute, from: date))
        let hourDecimal = hour + minute / 60.0

        // Solar noon approximation (simplified — doesn't account for timezone/longitude)
        let solarNoon = 12.0

        // Time-of-day factor: peak at solar noon, zero at sunrise/sunset
        // Using cosine with period matching ~10 hours of effective daylight
        let hourAngle = Double.pi * (hourDecimal - solarNoon) / 7.0
        let timeFactor = max(cos(hourAngle), 0.0)

        // Seasonal factor: peak in summer
        let peakDay: Double = location.latitude >= 0 ? 172.0 : 355.0
        let seasonPhase = 2.0 * Double.pi * (dayOfYear - peakDay) / 365.25
        let seasonFactor = (1.0 + cos(seasonPhase)) / 2.0

        // Latitude factor: lower latitudes → higher UV
        let absLat = abs(location.latitude)
        let latFactor = max(1.0 - absLat / 90.0, 0.1)

        // Peak UV index at the equator in summer at noon: ~12
        let peakUVI = 12.0

        return peakUVI * latFactor * seasonFactor * timeFactor
    }
}
