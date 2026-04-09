import XCTest
@testable import VitaminDTrackerCore

final class BaselineEstimatorTests: XCTestCase {

    // MARK: - Baseline Estimation

    func testBaselineEstimateReturnsReasonableValue() {
        let location = HomeLocation(cityName: "New York", latitude: 40.7, longitude: -74.0)
        let baseline = BaselineEstimator.estimateBaseline(location: location)
        // Should be in a reasonable range (5-60 ng/mL)
        XCTAssertGreaterThanOrEqual(baseline, 5.0)
        XCTAssertLessThanOrEqual(baseline, 60.0)
    }

    func testLowerLatitudeGivesHigherBaseline() {
        let miami = HomeLocation(cityName: "Miami", latitude: 25.7, longitude: -80.2)
        let seattle = HomeLocation(cityName: "Seattle", latitude: 47.6, longitude: -122.3)

        // Use same date for fair comparison (summer to isolate latitude effect)
        let summerDate = makeDateForJune15()

        let miamiBaseline = BaselineEstimator.estimateBaseline(location: miami, date: summerDate)
        let seattleBaseline = BaselineEstimator.estimateBaseline(location: seattle, date: summerDate)

        XCTAssertGreaterThan(miamiBaseline, seattleBaseline)
    }

    func testEquatorialLocationHasHigherBaseline() {
        let equator = HomeLocation(cityName: "Equator City", latitude: 0.0, longitude: 0.0)
        let arctic = HomeLocation(cityName: "Arctic", latitude: 65.0, longitude: 0.0)

        let summerDate = makeDateForJune15()
        let eqBaseline = BaselineEstimator.estimateBaseline(location: equator, date: summerDate)
        let arcticBaseline = BaselineEstimator.estimateBaseline(location: arctic, date: summerDate)

        XCTAssertGreaterThan(eqBaseline, arcticBaseline)
    }

    // MARK: - Seasonal Effects

    func testSummerHigherThanWinterNorthernHemisphere() {
        let nyc = HomeLocation(cityName: "New York", latitude: 40.7, longitude: -74.0)

        let summerDate = makeDateForJune15()
        let winterDate = makeDateForDecember15()

        let summerBaseline = BaselineEstimator.estimateBaseline(location: nyc, date: summerDate)
        let winterBaseline = BaselineEstimator.estimateBaseline(location: nyc, date: winterDate)

        XCTAssertGreaterThan(summerBaseline, winterBaseline)
    }

    func testSouthernHemisphereOppositeSeasons() {
        let sydney = HomeLocation(cityName: "Sydney", latitude: -33.9, longitude: 151.2)

        let june = makeDateForJune15()         // Winter in Sydney
        let december = makeDateForDecember15() // Summer in Sydney

        let juneBaseline = BaselineEstimator.estimateBaseline(location: sydney, date: june)
        let decemberBaseline = BaselineEstimator.estimateBaseline(location: sydney, date: december)

        // December should be higher (summer in southern hemisphere)
        XCTAssertGreaterThan(decemberBaseline, juneBaseline)
    }

    // MARK: - UV Index Estimation

    func testUVIndexPositiveDuringDay() {
        let miami = HomeLocation(cityName: "Miami", latitude: 25.7, longitude: -80.2)
        // Create a noon time in summer
        let noonSummer = makeNoonDate(month: 6, day: 15, utcOffsetHours: -5)
        let uvi = BaselineEstimator.estimateUVIndex(location: miami, date: noonSummer)
        XCTAssertGreaterThan(uvi, 0.0)
    }

    func testUVIndexHigherAtLowerLatitude() {
        let miami = HomeLocation(cityName: "Miami", latitude: 25.7, longitude: -80.2)
        let anchorage = HomeLocation(cityName: "Anchorage", latitude: 61.2, longitude: -149.9)

        // Each city gets its own local-noon instant — comparing the same
        // UTC instant would put Anchorage at 7 AM, which proves nothing.
        let miamiNoon = makeNoonDate(month: 6, day: 15, utcOffsetHours: -5)
        let anchorageNoon = makeNoonDate(month: 6, day: 15, utcOffsetHours: -10)
        let miamiUV = BaselineEstimator.estimateUVIndex(location: miami, date: miamiNoon)
        let anchorageUV = BaselineEstimator.estimateUVIndex(location: anchorage, date: anchorageNoon)

        XCTAssertGreaterThan(miamiUV, anchorageUV)
    }

    // MARK: - Latitude Effect

    func testLatitudeEffectAtEquator() {
        let effect = BaselineEstimator.latitudeEffect(latitude: 0.0)
        XCTAssertGreaterThan(effect, 0.0) // Positive adjustment near equator
    }

    func testLatitudeEffectAtHighLatitude() {
        let effect = BaselineEstimator.latitudeEffect(latitude: 60.0)
        XCTAssertLessThan(effect, 0.0) // Negative adjustment at high latitude
    }

    func testLatitudeEffectSymmetricForHemispheres() {
        let northEffect = BaselineEstimator.latitudeEffect(latitude: 45.0)
        let southEffect = BaselineEstimator.latitudeEffect(latitude: -45.0)
        XCTAssertEqual(northEffect, southEffect, accuracy: 0.001)
    }

    // MARK: - UV Index Minimum Threshold

    func testMinimumUVIndexForVitaminDIsThree() {
        XCTAssertEqual(ModelingAssumptions.minimumUVIndexForVitaminD, 3.0)
    }

    func testUVIndexZeroAtNight() {
        let nyc = HomeLocation(cityName: "New York", latitude: 40.7, longitude: -74.0)
        let nightDate = makeDate(month: 6, day: 15, hour: 23, minute: 0, utcOffsetHours: -5)
        let uvi = BaselineEstimator.estimateUVIndex(location: nyc, date: nightDate)
        XCTAssertEqual(uvi, 0.0, accuracy: 0.001,
            "UV index at 11 PM should be zero")
    }

    func testUVIndexAboveThresholdAtMiddaySummer() {
        let nyc = HomeLocation(cityName: "New York", latitude: 40.7, longitude: -74.0)
        let noonSummer = makeNoonDate(month: 6, day: 15, utcOffsetHours: -5)
        let uvi = BaselineEstimator.estimateUVIndex(location: nyc, date: noonSummer)
        XCTAssertGreaterThanOrEqual(uvi, ModelingAssumptions.minimumUVIndexForVitaminD,
            "UV index at noon in summer should meet the vitamin D production threshold")
    }

    func testUVIndexZeroLateAtNight() {
        let miami = HomeLocation(cityName: "Miami", latitude: 25.7, longitude: -80.2)
        let lateNight = makeDate(month: 7, day: 1, hour: 22, minute: 30, utcOffsetHours: -5)
        let uvi = BaselineEstimator.estimateUVIndex(location: miami, date: lateNight)
        XCTAssertEqual(uvi, 0.0, accuracy: 0.001,
            "UV index at 10:30 PM should be zero")
    }

    func testUVIndexZeroAtEarlyMorning() {
        let cabo = HomeLocation(cityName: "Cabo San Lucas", country: "Mexico",
                                latitude: 22.89, longitude: -109.92)
        let earlyMorning = makeDate(month: 4, day: 7, hour: 3, minute: 0, utcOffsetHours: -7)
        let uvi = BaselineEstimator.estimateUVIndex(location: cabo, date: earlyMorning)
        XCTAssertEqual(uvi, 0.0, accuracy: 0.001,
            "UV index at 3 AM should be zero")
    }

    // MARK: - Tropical UV (latitude/season coupling)

    func testTropicalNoonUVIsHighInSpring() {
        // Regression: Cabo (~23°N) at noon in early April should be UV ~10–11.
        // The previous independent seasonFactor × latFactor model put it ~5.7
        // because the seasonal swing was applied uniformly to every latitude.
        let cabo = HomeLocation(cityName: "Cabo San Lucas", country: "Mexico",
                                latitude: 22.89, longitude: -109.92)
        let noonApril = makeNoonDate(month: 4, day: 7, utcOffsetHours: -7)
        let uvi = BaselineEstimator.estimateUVIndex(location: cabo, date: noonApril)
        XCTAssertGreaterThan(uvi, 9.0,
            "Cabo at noon in April should have very high UV (~10+), got \(uvi)")
    }

    func testTropicalNoonUVNonZeroAtWinterSolstice() {
        // Regression: a season factor that swings 0→1 independent of latitude
        // would force UV to ~0 at the winter solstice — wrong for the tropics.
        let cabo = HomeLocation(cityName: "Cabo San Lucas", country: "Mexico",
                                latitude: 22.89, longitude: -109.92)
        let noonDecSolstice = makeNoonDate(month: 12, day: 21, utcOffsetHours: -7)
        let uvi = BaselineEstimator.estimateUVIndex(location: cabo, date: noonDecSolstice)
        XCTAssertGreaterThanOrEqual(uvi, ModelingAssumptions.minimumUVIndexForVitaminD,
            "Cabo at noon on the winter solstice should still produce vitamin D, got UV \(uvi)")
    }

    func testEquatorialNoonUVRoughlyConstantYearRound() {
        // The equator's noon solar elevation only varies between ~66.5° and 90°,
        // so UV should stay high in every month.
        let equator = HomeLocation(cityName: "Equator", latitude: 0.0, longitude: 0.0)
        for month in 1...12 {
            let noon = makeNoonDate(month: month, day: 15, utcOffsetHours: 0)
            let uvi = BaselineEstimator.estimateUVIndex(location: equator, date: noon)
            XCTAssertGreaterThan(uvi, 8.0,
                "Equator at noon should have UV > 8 year-round; month \(month) gave \(uvi)")
        }
    }

    func testHighLatitudeStillHasLargeSeasonalSwing() {
        // Make sure coupling didn't kill seasonal variation where it belongs.
        let seattle = HomeLocation(cityName: "Seattle", latitude: 47.6, longitude: -122.3)
        let summerUV = BaselineEstimator.estimateUVIndex(location: seattle, date: makeNoonDate(month: 6, day: 21, utcOffsetHours: -8))
        let winterUV = BaselineEstimator.estimateUVIndex(location: seattle, date: makeNoonDate(month: 12, day: 21, utcOffsetHours: -8))
        XCTAssertGreaterThan(summerUV, winterUV * 5.0,
            "Seattle's noon UV should swing dramatically between summer (\(summerUV)) and winter (\(winterUV))")
    }

    // MARK: - Morning UV curve shape

    func testTropicalEarlyMorningUVIsLow() {
        // Regression: Cabo at 7:30 AM in early April. The old model computed
        // sin^2.5 attenuation only at the noon elevation and then scaled it
        // with a gentle cos(t) for time of day, giving ~4.5. The actual sun
        // is only ~19° above the horizon at this hour; applying sin^2.5 to
        // *that* elevation gives < 1. Real-world reports were ~2.
        let cabo = HomeLocation(cityName: "Cabo San Lucas", country: "Mexico",
                                latitude: 22.89, longitude: -109.92)
        let morning = makeDate(month: 4, day: 8, hour: 7, minute: 30, utcOffsetHours: -7)
        let uvi = BaselineEstimator.estimateUVIndex(location: cabo, date: morning)
        XCTAssertLessThan(uvi, 2.0,
            "Cabo at 7:30 AM in April should be well below the vitamin D " +
            "threshold; old model said \(4.5), got \(uvi)")
        XCTAssertGreaterThan(uvi, 0.0, "Sun is up at 7:30 AM in Cabo")
    }

    func testMidMorningRampsSteeplyTowardNoon() {
        // The point of instantaneous elevation: the curve is concave-up in
        // the morning. UV at 10 AM should be much closer to the noon value
        // than to the 8 AM value.
        let cabo = HomeLocation(cityName: "Cabo San Lucas", country: "Mexico",
                                latitude: 22.89, longitude: -109.92)
        let uv8  = BaselineEstimator.estimateUVIndex(location: cabo, date: makeDate(month: 4, day: 8, hour: 8,  minute: 0, utcOffsetHours: -7))
        let uv10 = BaselineEstimator.estimateUVIndex(location: cabo, date: makeDate(month: 4, day: 8, hour: 10, minute: 0, utcOffsetHours: -7))
        let uv12 = BaselineEstimator.estimateUVIndex(location: cabo, date: makeDate(month: 4, day: 8, hour: 12, minute: 0, utcOffsetHours: -7))

        XCTAssertGreaterThan(uv10 - uv8, uv12 - uv10,
            "UV ramp from 8→10 should be steeper than 10→12 (concave); " +
            "got 8AM=\(uv8), 10AM=\(uv10), 12PM=\(uv12)")
    }

    // MARK: - Daylight Duration

    func testDaylightLongerInSummerThanWinter() {
        // Seattle: ~16h daylight in June, ~8h in December
        let summerHalf = BaselineEstimator.daylightHalfLength(latitude: 47.6, dayOfYear: 172)
        let winterHalf = BaselineEstimator.daylightHalfLength(latitude: 47.6, dayOfYear: 355)
        XCTAssertGreaterThan(summerHalf, winterHalf,
            "Seattle should have longer daylight in summer than winter")
        XCTAssertGreaterThan(summerHalf, 7.0, "Seattle summer half-day should be > 7h")
        XCTAssertLessThan(winterHalf, 5.0, "Seattle winter half-day should be < 5h")
    }

    func testDaylightNearlyConstantAtEquator() {
        let juneHalf = BaselineEstimator.daylightHalfLength(latitude: 0.0, dayOfYear: 172)
        let decHalf = BaselineEstimator.daylightHalfLength(latitude: 0.0, dayOfYear: 355)
        XCTAssertEqual(juneHalf, decHalf, accuracy: 0.1,
            "Equator should have nearly constant daylight year-round")
        XCTAssertEqual(juneHalf, 6.0, accuracy: 0.2,
            "Equator half-day should be ~6 hours")
    }

    func testPolarDayInArcticSummer() {
        // North of Arctic Circle (~66.5°) in June = midnight sun
        let halfDay = BaselineEstimator.daylightHalfLength(latitude: 70.0, dayOfYear: 172)
        XCTAssertEqual(halfDay, 12.0, accuracy: 0.001,
            "Above Arctic Circle in summer should have 24h daylight")
    }

    func testPolarNightInArcticWinter() {
        // North of Arctic Circle in December = polar night
        let halfDay = BaselineEstimator.daylightHalfLength(latitude: 70.0, dayOfYear: 355)
        XCTAssertEqual(halfDay, 0.0, accuracy: 0.001,
            "Above Arctic Circle in winter should have 0h daylight")
    }

    func testUVNonZeroAt7PMInSeattleSummer() {
        // Seattle in June: sunset is ~9 PM, so 7 PM should still have UV
        let seattle = HomeLocation(cityName: "Seattle", country: "US",
                                   latitude: 47.6, longitude: -122.3)
        let eveningSummer = makeDate(month: 6, day: 21, hour: 19, minute: 0, utcOffsetHours: -8)
        let uvi = BaselineEstimator.estimateUVIndex(location: seattle, date: eveningSummer)
        XCTAssertGreaterThan(uvi, 0.0,
            "Seattle at 7 PM in June should still have some UV")
    }

    func testUVZeroAt7PMInSeattleWinter() {
        // Seattle in December: sunset is ~4:20 PM, so 7 PM should be zero
        let seattle = HomeLocation(cityName: "Seattle", country: "US",
                                   latitude: 47.6, longitude: -122.3)
        let eveningWinter = makeDate(month: 12, day: 21, hour: 19, minute: 0, utcOffsetHours: -8)
        let uvi = BaselineEstimator.estimateUVIndex(location: seattle, date: eveningWinter)
        XCTAssertEqual(uvi, 0.0, accuracy: 0.001,
            "Seattle at 7 PM in December should have zero UV")
    }

    // MARK: - Skin-Type Adjustment to Baseline

    func testSkinTypeNilOrTypeIIIsNoOp() {
        let nyc = HomeLocation(cityName: "New York", latitude: 40.7, longitude: -74.0)
        let date = makeDateForJune15()

        let none = BaselineEstimator.estimateBaseline(location: nyc, date: date, skinType: nil)
        let typeII = BaselineEstimator.estimateBaseline(location: nyc, date: date, skinType: .typeII)

        XCTAssertEqual(none, typeII, accuracy: 1e-9,
            "Type II is the reference (multiplier 1.0) so it must equal the nil case exactly")
    }

    func testDarkerSkinTypeGivesLowerBaseline() {
        let miami = HomeLocation(cityName: "Miami", latitude: 25.7, longitude: -80.2)
        let date = makeDateForJune15()

        let typeI  = BaselineEstimator.estimateBaseline(location: miami, date: date, skinType: .typeI)
        let typeII = BaselineEstimator.estimateBaseline(location: miami, date: date, skinType: .typeII)
        let typeVI = BaselineEstimator.estimateBaseline(location: miami, date: date, skinType: .typeVI)

        XCTAssertGreaterThan(typeI, typeII,
            "Type I (multiplier 1.2) should land above the reference")
        XCTAssertGreaterThan(typeII, typeVI,
            "Type VI (multiplier 0.20) should land well below the reference")
    }

    func testSkinTypeOnlyScalesSunPortionNotDietFloor() {
        // Pick a location/date with a healthy sun-derived portion so the math
        // is observable above the clamp.
        let miami = HomeLocation(cityName: "Miami", latitude: 25.7, longitude: -80.2)
        let date = makeDateForJune15()
        let dietFloor = ModelingAssumptions.dietaryBaselineFloorNgML

        let typeII = BaselineEstimator.estimateBaseline(location: miami, date: date, skinType: .typeII)
        let typeIV = BaselineEstimator.estimateBaseline(location: miami, date: date, skinType: .typeIV)

        // Reconstruct the type-IV result by hand: scale the sun portion of
        // the type-II baseline by the type-IV production multiplier, then
        // add the diet floor back. Both values are well inside [5, 60] for
        // Miami in June so the clamp is irrelevant.
        let sunPortionII = typeII - dietFloor
        let expectedIV = sunPortionII * FitzpatrickSkinType.typeIV.vitaminDProductionMultiplier + dietFloor
        XCTAssertEqual(typeIV, expectedIV, accuracy: 1e-6)
        XCTAssertGreaterThan(typeIV, dietFloor,
            "Diet floor must remain even when the sun portion is heavily attenuated")
    }

    // MARK: - Helpers

    /// Builds a `Date` at a fixed UTC offset so the resulting *instant* is
    /// independent of the test machine's locale. The estimator now reads
    /// dates in UTC and derives the solar hour angle from longitude, so
    /// "noon" must mean "noon at a clock matching the test location's
    /// longitude" — pick `utcOffsetHours ≈ round(longitude / 15)`.
    ///
    /// (Before this change, tests passed only by coincidence when the dev
    /// machine happened to be in a US timezone.)
    private func makeDate(month: Int, day: Int, hour: Int, minute: Int,
                          utcOffsetHours: Int) -> Date {
        var components = DateComponents()
        components.year = 2025
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.timeZone = TimeZone(secondsFromGMT: utcOffsetHours * 3600)
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    private func makeDateForJune15() -> Date {
        var components = DateComponents()
        components.year = 2025
        components.month = 6
        components.day = 15
        components.hour = 12
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    private func makeDateForDecember15() -> Date {
        var components = DateComponents()
        components.year = 2025
        components.month = 12
        components.day = 15
        components.hour = 12
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    private func makeNoonDate(month: Int, day: Int, utcOffsetHours: Int) -> Date {
        makeDate(month: month, day: day, hour: 12, minute: 0,
                 utcOffsetHours: utcOffsetHours)
    }
}
