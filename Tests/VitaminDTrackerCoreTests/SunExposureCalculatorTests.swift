import XCTest
@testable import VitaminDTrackerCore

final class SunExposureCalculatorTests: XCTestCase {

    // MARK: - Basic Vitamin D Gain

    func testZeroUVIndexGivesNoGain() {
        let gain = SunExposureCalculator.estimateVitaminDGain(
            uvIndex: 0.0,
            skinExposureFraction: 0.5,
            cloudCoverFraction: 0.0,
            durationMinutes: 30.0
        )
        XCTAssertEqual(gain, 0.0, accuracy: 0.001)
    }

    func testZeroSkinExposureGivesNoGain() {
        let gain = SunExposureCalculator.estimateVitaminDGain(
            uvIndex: 7.0,
            skinExposureFraction: 0.0,
            cloudCoverFraction: 0.0,
            durationMinutes: 30.0
        )
        XCTAssertEqual(gain, 0.0, accuracy: 0.001)
    }

    func testZeroDurationGivesNoGain() {
        let gain = SunExposureCalculator.estimateVitaminDGain(
            uvIndex: 7.0,
            skinExposureFraction: 0.5,
            cloudCoverFraction: 0.0,
            durationMinutes: 0.0
        )
        XCTAssertEqual(gain, 0.0, accuracy: 0.001)
    }

    func testPositiveGainWithValidInputs() {
        let gain = SunExposureCalculator.estimateVitaminDGain(
            uvIndex: 7.0,
            skinExposureFraction: 0.5,
            cloudCoverFraction: 0.0,
            durationMinutes: 15.0
        )
        XCTAssertGreaterThan(gain, 0.0)
    }

    // MARK: - Scaling Behavior

    func testHigherUVGivesMoreGain() {
        let gainLow = SunExposureCalculator.estimateVitaminDGain(
            uvIndex: 3.0,
            skinExposureFraction: 0.5,
            cloudCoverFraction: 0.0,
            durationMinutes: 15.0
        )
        let gainHigh = SunExposureCalculator.estimateVitaminDGain(
            uvIndex: 9.0,
            skinExposureFraction: 0.5,
            cloudCoverFraction: 0.0,
            durationMinutes: 15.0
        )
        XCTAssertGreaterThan(gainHigh, gainLow)
    }

    func testMoreSkinExposureGivesMoreGain() {
        let gainLow = SunExposureCalculator.estimateVitaminDGain(
            uvIndex: 7.0,
            skinExposureFraction: 0.25,
            cloudCoverFraction: 0.0,
            durationMinutes: 15.0
        )
        let gainHigh = SunExposureCalculator.estimateVitaminDGain(
            uvIndex: 7.0,
            skinExposureFraction: 0.75,
            cloudCoverFraction: 0.0,
            durationMinutes: 15.0
        )
        XCTAssertGreaterThan(gainHigh, gainLow)
    }

    func testCloudCoverReducesGain() {
        let gainClear = SunExposureCalculator.estimateVitaminDGain(
            uvIndex: 7.0,
            skinExposureFraction: 0.5,
            cloudCoverFraction: 0.0,
            durationMinutes: 15.0
        )
        let gainCloudy = SunExposureCalculator.estimateVitaminDGain(
            uvIndex: 7.0,
            skinExposureFraction: 0.5,
            cloudCoverFraction: 0.8,
            durationMinutes: 15.0
        )
        XCTAssertGreaterThan(gainClear, gainCloudy)
    }

    func testFullCloudCoverStillAllowsSomeGain() {
        let gain = SunExposureCalculator.estimateVitaminDGain(
            uvIndex: 7.0,
            skinExposureFraction: 0.5,
            cloudCoverFraction: 1.0,
            durationMinutes: 15.0
        )
        // Even full cloud cover transmits ~25% of UV
        XCTAssertGreaterThan(gain, 0.0)
    }

    // MARK: - Diminishing Returns

    func testLongerDurationShowsDiminishingReturns() {
        let gain15 = SunExposureCalculator.estimateVitaminDGain(
            uvIndex: 10.0,
            skinExposureFraction: 0.5,
            cloudCoverFraction: 0.0,
            durationMinutes: 15.0
        )
        let gain30 = SunExposureCalculator.estimateVitaminDGain(
            uvIndex: 10.0,
            skinExposureFraction: 0.5,
            cloudCoverFraction: 0.0,
            durationMinutes: 30.0
        )
        let gain60 = SunExposureCalculator.estimateVitaminDGain(
            uvIndex: 10.0,
            skinExposureFraction: 0.5,
            cloudCoverFraction: 0.0,
            durationMinutes: 60.0
        )

        // Gain should increase with time but at a decreasing rate
        XCTAssertGreaterThan(gain30, gain15)
        XCTAssertGreaterThan(gain60, gain30)

        // The marginal gain of the second 15 min should be less than the first 15 min
        let firstHalfGain = gain15
        let secondHalfGain = gain30 - gain15
        XCTAssertGreaterThan(firstHalfGain, secondHalfGain)
    }

    // MARK: - Gain Rate

    func testCurrentGainRatePositive() {
        let rate = SunExposureCalculator.currentGainRate(
            uvIndex: 7.0,
            skinExposureFraction: 0.5,
            cloudCoverFraction: 0.0,
            elapsedMinutes: 5.0
        )
        XCTAssertGreaterThan(rate, 0.0)
    }

    func testGainRateDecreaseOverTime() {
        let rateEarly = SunExposureCalculator.currentGainRate(
            uvIndex: 10.0,
            skinExposureFraction: 0.5,
            cloudCoverFraction: 0.0,
            elapsedMinutes: 5.0
        )
        let rateLater = SunExposureCalculator.currentGainRate(
            uvIndex: 10.0,
            skinExposureFraction: 0.5,
            cloudCoverFraction: 0.0,
            elapsedMinutes: 60.0
        )
        XCTAssertGreaterThan(rateEarly, rateLater)
    }
}
