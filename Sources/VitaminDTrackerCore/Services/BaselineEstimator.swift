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
    /// This is the level a typical person at this location would settle at with
    /// **no supplements and no deliberately tracked sun sessions** — i.e. it
    /// reflects diet (~190 IU/day per NHANES 2015-16) plus *incidental* sun
    /// (walking to the car, errands, etc.). Per NIH ODS, the US population mean
    /// is ~24 ng/mL despite dietary intake that alone would only sustain ~2 ng/mL;
    /// the gap is incidental sun exposure that no one ever logs.
    ///
    /// The latitude and seasonal adjustments encode how that incidental-sun
    /// portion shrinks at high latitudes and in winter, and the optional
    /// `skinType` adjustment encodes how melanin attenuates it (NHANES shows
    /// ~10 ng/mL lower mean for non-Hispanic Black vs. White Americans).
    ///
    /// - Parameters:
    ///   - location: The user's home location.
    ///   - date: The date for the estimate (to account for seasonality).
    ///   - skinType: Fitzpatrick skin type. When provided, the sun-derived
    ///     portion of the baseline is scaled by `vitaminDProductionMultiplier`.
    ///     Diet is unaffected by melanin, so a small dietary floor is preserved.
    /// - Returns: Estimated 25(OH)D level in ng/mL.
    public static func estimateBaseline(
        location: HomeLocation,
        date: Date = Date(),
        skinType: FitzpatrickSkinType? = nil
    ) -> Double {
        let latitudeAdjustment = latitudeEffect(latitude: location.latitude)
        let seasonalAdjustment = seasonalEffect(latitude: location.latitude, date: date)

        let unadjusted = ModelingAssumptions.defaultBaselineNgML
            + latitudeAdjustment
            + seasonalAdjustment

        // Skin-type adjustment: scale only the sun-derived portion.
        // Dietary intake (~190 IU/day ≈ ~2 ng/mL at steady state) is unaffected
        // by melanin, so we hold that floor constant and apply the multiplier
        // to everything above it. With skinType nil or .typeII (multiplier 1.0)
        // this is a no-op.
        let dietFloor = ModelingAssumptions.dietaryBaselineFloorNgML
        let sunPortion = max(unadjusted - dietFloor, 0.0)
        let skinMultiplier = ModelingAssumptions.vitaminDProductionMultiplier(for: skinType)
        let baseline = sunPortion * skinMultiplier + dietFloor

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

    /// Estimate clear-sky UV index for a location at a specific instant.
    ///
    /// This is a self-contained astronomical model — no network, no weather
    /// data. It computes the sun's *instantaneous* elevation from latitude,
    /// longitude, day of year, and UTC time, then applies an empirical
    /// `sin(elevation)^2.5` power law for atmospheric attenuation (UV-B at
    /// low sun angles passes through a much longer slant column of ozone).
    ///
    /// Because the date is read in UTC and longitude is folded directly into
    /// the hour angle, the result is independent of the device's local
    /// timezone. `Date()` is just a point in time; this function never asks
    /// what wall clock the user is looking at.
    ///
    /// Known approximations:
    /// - Ignores the equation of time (~±15 min, varies through the year).
    /// - Day of year is read in UTC; near solar midnight it can be off by
    ///   one, but declination changes < 0.4°/day so the effect is negligible.
    /// - Clear-sky only. Real UV is lower under cloud, higher at altitude
    ///   and over snow. Use ``UVIndexProvider`` in the app target for
    ///   WeatherKit-backed values when network is available.
    ///
    /// - Parameters:
    ///   - location: Geographic location (latitude *and* longitude both used).
    ///   - date: The instant to evaluate. Defaults to now.
    /// - Returns: Estimated clear-sky UV index, 0 if the sun is below the horizon.
    public static func estimateUVIndex(
        location: HomeLocation,
        date: Date = Date()
    ) -> Double {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        let dayOfYear = Double(calendar.ordinality(of: .day, in: .year, for: date) ?? 1)
        let hour = Double(calendar.component(.hour, from: date))
        let minute = Double(calendar.component(.minute, from: date))
        let utcHour = hour + minute / 60.0

        let declRad = solarDeclinationDegrees(dayOfYear: dayOfYear) * .pi / 180.0
        let latRad = location.latitude * .pi / 180.0

        // Hour angle of the sun: 0 at local solar noon, ±180° at solar
        // midnight, 15° per hour. Solar noon at longitude L (degrees, east
        // positive) occurs at 12 − L/15 UTC, so:
        //   hourAngle = 15° × (utcHour − (12 − L/15))
        //             = 15° × (utcHour − 12) + L
        let hourAngleDeg = 15.0 * (utcHour - 12.0) + location.longitude
        let hourAngleRad = hourAngleDeg * .pi / 180.0

        // Instantaneous solar elevation. This is the standard altitude
        // formula — it folds latitude, season (via declination), and time
        // of day (via hour angle) into one number. There is no separate
        // "noon factor × time factor": that decomposition is what caused
        // the over-generous morning estimates (Cabo at 7:30 AM read ~5,
        // reality ~1–2) because a plain cosine on time doesn't fall off
        // nearly as steeply as the real atmosphere does at low sun.
        let sinElev = sin(latRad) * sin(declRad)
                    + cos(latRad) * cos(declRad) * cos(hourAngleRad)

        guard sinElev > 0 else { return 0.0 }   // sun below horizon

        // Peak UV index when the sun is directly overhead: ~12 (clear sky,
        // sea level, typical ozone column). The 2.5 exponent approximates
        // the optical-air-mass effect on erythemal irradiance.
        let peakUVI = 12.0
        return peakUVI * pow(sinElev, 2.5)
    }

    /// Solar declination angle in degrees for a given day of the year.
    /// Ranges from ≈ −23.45° (Dec solstice) to ≈ +23.45° (Jun solstice).
    static func solarDeclinationDegrees(dayOfYear: Double) -> Double {
        23.45 * sin(2.0 * Double.pi * (284.0 + dayOfYear) / 365.0)
    }

    /// Computes the number of hours from solar noon to sunset (half the daylight period).
    /// Uses the standard astronomical day-length formula based on solar declination and latitude.
    ///
    /// No longer used by ``estimateUVIndex(location:date:)`` (which now
    /// computes instantaneous elevation directly), but kept for callers that
    /// need sunrise/sunset times rather than UV intensity.
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
