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
    /// Daylight duration is computed from solar declination and latitude,
    /// so sunrise/sunset times vary correctly by season and location.
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

        // Calculate half-day length from solar declination and latitude
        let halfDayHours = daylightHalfLength(latitude: location.latitude, dayOfYear: dayOfYear)

        // Time-of-day factor: peak at solar noon, zero at sunrise/sunset
        // Use a cosine scaled so it equals 1 at noon and 0 at sunrise/sunset
        let hoursFromNoon = abs(hourDecimal - solarNoon)
        let timeFactor: Double
        if halfDayHours <= 0 || hoursFromNoon >= halfDayHours {
            timeFactor = 0.0
        } else {
            let hourAngle = (Double.pi / 2.0) * hoursFromNoon / halfDayHours
            timeFactor = cos(hourAngle)
        }

        // Noon UV intensity from solar elevation.
        //
        // Latitude and season are NOT independent — they couple through solar
        // elevation: noonElevation = 90° − |latitude − declination|. Modeling
        // them as separate multiplicative factors over-attenuates the tropics
        // away from the summer solstice (e.g. it would put Cabo near UV 0 in
        // December, when reality is UV ~6–7 at noon).
        //
        // The sin^2.5 exponent approximates atmospheric attenuation: at lower
        // sun angles, UV-B passes through more atmosphere and ozone.
        let declinationDeg = solarDeclinationDegrees(dayOfYear: dayOfYear)
        let noonElevationDeg = 90.0 - abs(location.latitude - declinationDeg)
        guard noonElevationDeg > 0 else { return 0.0 }   // polar night
        let noonElevationRad = noonElevationDeg * Double.pi / 180.0
        let elevationFactor = pow(sin(noonElevationRad), 2.5)

        // Peak UV index when the sun is directly overhead at noon: ~12
        let peakUVI = 12.0

        return peakUVI * elevationFactor * timeFactor
    }

    /// Solar declination angle in degrees for a given day of the year.
    /// Ranges from ≈ −23.45° (Dec solstice) to ≈ +23.45° (Jun solstice).
    static func solarDeclinationDegrees(dayOfYear: Double) -> Double {
        23.45 * sin(2.0 * Double.pi * (284.0 + dayOfYear) / 365.0)
    }

    /// Computes the number of hours from solar noon to sunset (half the daylight period).
    /// Uses the standard astronomical day-length formula based on solar declination and latitude.
    ///
    /// Returns 0 for polar night, 12 for polar day (midnight sun).
    static func daylightHalfLength(latitude: Double, dayOfYear: Double) -> Double {
        let latRad = latitude * Double.pi / 180.0
        let declination = solarDeclinationDegrees(dayOfYear: dayOfYear) * Double.pi / 180.0

        let cosHourAngle = -tan(latRad) * tan(declination)

        // Polar night: sun never rises
        if cosHourAngle > 1.0 { return 0.0 }
        // Polar day (midnight sun): sun never sets
        if cosHourAngle < -1.0 { return 12.0 }

        let hourAngleRad = acos(cosHourAngle)
        return hourAngleRad * 12.0 / Double.pi  // convert radians to hours
    }
}
