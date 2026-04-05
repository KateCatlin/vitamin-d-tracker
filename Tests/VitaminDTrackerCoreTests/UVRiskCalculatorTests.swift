import XCTest
@testable import VitaminDTrackerCore

final class UVRiskCalculatorTests: XCTestCase {

    // MARK: - Risk Level Classification

    func testLowUVRiskLevel() {
        XCTAssertEqual(UVRiskCalculator.riskLevel(uvIndex: 1.0), .low)
        XCTAssertEqual(UVRiskCalculator.riskLevel(uvIndex: 2.9), .low)
    }

    func testModerateUVRiskLevel() {
        XCTAssertEqual(UVRiskCalculator.riskLevel(uvIndex: 3.0), .moderate)
        XCTAssertEqual(UVRiskCalculator.riskLevel(uvIndex: 5.9), .moderate)
    }

    func testHighUVRiskLevel() {
        XCTAssertEqual(UVRiskCalculator.riskLevel(uvIndex: 6.0), .high)
        XCTAssertEqual(UVRiskCalculator.riskLevel(uvIndex: 7.9), .high)
    }

    func testVeryHighUVRiskLevel() {
        XCTAssertEqual(UVRiskCalculator.riskLevel(uvIndex: 8.0), .veryHigh)
        XCTAssertEqual(UVRiskCalculator.riskLevel(uvIndex: 10.9), .veryHigh)
    }

    func testExtremeUVRiskLevel() {
        XCTAssertEqual(UVRiskCalculator.riskLevel(uvIndex: 11.0), .extreme)
        XCTAssertEqual(UVRiskCalculator.riskLevel(uvIndex: 15.0), .extreme)
    }

    // MARK: - SED Accumulation

    func testSEDAccumulationIncreasesWithTime() {
        let sed10 = UVRiskCalculator.accumulatedSED(uvIndex: 7.0, durationMinutes: 10.0)
        let sed20 = UVRiskCalculator.accumulatedSED(uvIndex: 7.0, durationMinutes: 20.0)
        XCTAssertGreaterThan(sed20, sed10)
        XCTAssertEqual(sed20, sed10 * 2.0, accuracy: 0.001)
    }

    func testSEDAccumulationIncreasesWithUV() {
        let sedLow = UVRiskCalculator.accumulatedSED(uvIndex: 3.0, durationMinutes: 30.0)
        let sedHigh = UVRiskCalculator.accumulatedSED(uvIndex: 9.0, durationMinutes: 30.0)
        XCTAssertGreaterThan(sedHigh, sedLow)
    }

    func testCloudCoverReducesSED() {
        let sedClear = UVRiskCalculator.accumulatedSED(
            uvIndex: 7.0, durationMinutes: 30.0, cloudCoverFraction: 0.0
        )
        let sedCloudy = UVRiskCalculator.accumulatedSED(
            uvIndex: 7.0, durationMinutes: 30.0, cloudCoverFraction: 0.5
        )
        XCTAssertGreaterThan(sedClear, sedCloudy)
    }

    // MARK: - Maximum Safe Exposure

    func testMaxSafeExposureReturnsPositiveValue() {
        let maxTime = UVRiskCalculator.maxSafeExposureMinutes(uvIndex: 7.0)
        XCTAssertNotNil(maxTime)
        XCTAssertGreaterThan(maxTime!, 0.0)
    }

    func testMaxSafeExposureShorterAtHigherUV() {
        let maxTimeLow = UVRiskCalculator.maxSafeExposureMinutes(uvIndex: 3.0)!
        let maxTimeHigh = UVRiskCalculator.maxSafeExposureMinutes(uvIndex: 10.0)!
        XCTAssertGreaterThan(maxTimeLow, maxTimeHigh)
    }

    func testMaxSafeExposureNilAtZeroUV() {
        let maxTime = UVRiskCalculator.maxSafeExposureMinutes(uvIndex: 0.0)
        XCTAssertNil(maxTime)
    }

    func testMaxSafeExposureLongerWithClouds() {
        let maxClear = UVRiskCalculator.maxSafeExposureMinutes(uvIndex: 7.0, cloudCoverFraction: 0.0)!
        let maxCloudy = UVRiskCalculator.maxSafeExposureMinutes(uvIndex: 7.0, cloudCoverFraction: 0.5)!
        XCTAssertGreaterThan(maxCloudy, maxClear)
    }

    // MARK: - Overexposure Detection

    func testNotOverexposedShortDuration() {
        let result = UVRiskCalculator.isOverexposed(
            uvIndex: 5.0,
            durationMinutes: 5.0
        )
        XCTAssertFalse(result)
    }

    func testOverexposedLongDurationHighUV() {
        let result = UVRiskCalculator.isOverexposed(
            uvIndex: 10.0,
            durationMinutes: 60.0
        )
        XCTAssertTrue(result)
    }

    func testOverexposureMatchesMaxSafe() {
        let uvIndex = 7.0
        let maxSafe = UVRiskCalculator.maxSafeExposureMinutes(uvIndex: uvIndex)!

        // Just under the limit should be safe
        XCTAssertFalse(UVRiskCalculator.isOverexposed(
            uvIndex: uvIndex,
            durationMinutes: maxSafe - 1.0
        ))

        // At or over the limit should warn
        XCTAssertTrue(UVRiskCalculator.isOverexposed(
            uvIndex: uvIndex,
            durationMinutes: maxSafe + 1.0
        ))
    }

    // MARK: - Exposure Percentage

    func testExposurePercentageZero() {
        let pct = UVRiskCalculator.exposurePercentage(
            uvIndex: 7.0,
            durationMinutes: 0.0
        )
        XCTAssertEqual(pct, 0.0, accuracy: 0.001)
    }

    func testExposurePercentageIncreases() {
        let pct1 = UVRiskCalculator.exposurePercentage(uvIndex: 7.0, durationMinutes: 5.0)
        let pct2 = UVRiskCalculator.exposurePercentage(uvIndex: 7.0, durationMinutes: 15.0)
        XCTAssertGreaterThan(pct2, pct1)
    }

    func testExposurePercentageExceedsOneWhenOverexposed() {
        let pct = UVRiskCalculator.exposurePercentage(
            uvIndex: 10.0,
            durationMinutes: 120.0
        )
        XCTAssertGreaterThan(pct, 1.0)
    }

    // MARK: - Warning Behavior

    func testLowRiskDoesNotWarn() {
        XCTAssertFalse(UVRiskLevel.low.shouldWarn)
        XCTAssertFalse(UVRiskLevel.moderate.shouldWarn)
    }

    func testHighRiskWarns() {
        XCTAssertTrue(UVRiskLevel.high.shouldWarn)
        XCTAssertTrue(UVRiskLevel.veryHigh.shouldWarn)
        XCTAssertTrue(UVRiskLevel.extreme.shouldWarn)
    }
}
