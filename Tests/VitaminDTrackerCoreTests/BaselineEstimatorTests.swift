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
        let noonSummer = makeNoonDate(month: 6, day: 15)
        let uvi = BaselineEstimator.estimateUVIndex(location: miami, date: noonSummer)
        XCTAssertGreaterThan(uvi, 0.0)
    }

    func testUVIndexHigherAtLowerLatitude() {
        let miami = HomeLocation(cityName: "Miami", latitude: 25.7, longitude: -80.2)
        let anchorage = HomeLocation(cityName: "Anchorage", latitude: 61.2, longitude: -149.9)

        let noonSummer = makeNoonDate(month: 6, day: 15)
        let miamiUV = BaselineEstimator.estimateUVIndex(location: miami, date: noonSummer)
        let anchorageUV = BaselineEstimator.estimateUVIndex(location: anchorage, date: noonSummer)

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

    func testUVIndexBelowThresholdAtNight() {
        let nyc = HomeLocation(cityName: "New York", latitude: 40.7, longitude: -74.0)
        let nightDate = makeDate(month: 6, day: 15, hour: 23, minute: 0)
        let uvi = BaselineEstimator.estimateUVIndex(location: nyc, date: nightDate)
        XCTAssertEqual(uvi, 0.0, accuracy: 0.001,
            "UV index at 11 PM should be zero")
    }

    func testUVIndexAboveThresholdAtMiddaySummer() {
        let nyc = HomeLocation(cityName: "New York", latitude: 40.7, longitude: -74.0)
        let noonSummer = makeNoonDate(month: 6, day: 15)
        let uvi = BaselineEstimator.estimateUVIndex(location: nyc, date: noonSummer)
        XCTAssertGreaterThanOrEqual(uvi, ModelingAssumptions.minimumUVIndexForVitaminD,
            "UV index at noon in summer should meet the vitamin D production threshold")
    }

    func testUVIndexLowLateAtNight() {
        let miami = HomeLocation(cityName: "Miami", latitude: 25.7, longitude: -80.2)
        let lateNight = makeDate(month: 7, day: 1, hour: 22, minute: 30)
        let uvi = BaselineEstimator.estimateUVIndex(location: miami, date: lateNight)
        XCTAssertEqual(uvi, 0.0, accuracy: 0.001,
            "UV index at 10:30 PM should be zero")
    }

    func testUVIndexZeroAtEarlyMorning() {
        let cabo = HomeLocation(cityName: "Cabo San Lucas", country: "Mexico",
                                latitude: 22.89, longitude: -109.92)
        let earlyMorning = makeDate(month: 4, day: 7, hour: 3, minute: 0)
        let uvi = BaselineEstimator.estimateUVIndex(location: cabo, date: earlyMorning)
        XCTAssertEqual(uvi, 0.0, accuracy: 0.001,
            "UV index at 3 AM should be zero")
    }

    // MARK: - Helpers

    private func makeDate(month: Int, day: Int, hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.year = 2025
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
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

    private func makeNoonDate(month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = 2025
        components.month = month
        components.day = day
        components.hour = 12
        components.minute = 0
        return Calendar(identifier: .gregorian).date(from: components)!
    }
}
