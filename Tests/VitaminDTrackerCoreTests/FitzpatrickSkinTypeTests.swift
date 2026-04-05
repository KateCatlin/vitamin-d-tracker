import XCTest
@testable import VitaminDTrackerCore

final class FitzpatrickSkinTypeTests: XCTestCase {

    // MARK: - Sunburn Threshold Tests

    func testTypeIHasLowestSunburnThreshold() {
        XCTAssertEqual(FitzpatrickSkinType.typeI.sunburnThresholdSED, 2.0, accuracy: 0.001)
    }

    func testTypeVIHasHighestSunburnThreshold() {
        XCTAssertEqual(FitzpatrickSkinType.typeVI.sunburnThresholdSED, 10.0, accuracy: 0.001)
    }

    func testSunburnThresholdsIncreaseWithDarkerSkin() {
        let types = FitzpatrickSkinType.allCases
        for i in 1..<types.count {
            XCTAssertGreaterThan(
                types[i].sunburnThresholdSED,
                types[i - 1].sunburnThresholdSED,
                "Type \(types[i].rawValue) should have higher threshold than type \(types[i - 1].rawValue)"
            )
        }
    }

    // MARK: - Vitamin D Production Multiplier Tests

    func testTypeIIIsReferenceMultiplier() {
        XCTAssertEqual(FitzpatrickSkinType.typeII.vitaminDProductionMultiplier, 1.0, accuracy: 0.001)
    }

    func testTypeIProducesMoreThanReference() {
        XCTAssertGreaterThan(FitzpatrickSkinType.typeI.vitaminDProductionMultiplier, 1.0)
    }

    func testDarkerSkinProducesLessVitaminD() {
        let types = FitzpatrickSkinType.allCases
        // Type I > Type II > ... > Type VI
        for i in 1..<types.count {
            XCTAssertLessThan(
                types[i].vitaminDProductionMultiplier,
                types[i - 1].vitaminDProductionMultiplier,
                "Type \(types[i].rawValue) should produce less vitamin D than type \(types[i - 1].rawValue)"
            )
        }
    }

    func testAllMultipliersArePositive() {
        for skinType in FitzpatrickSkinType.allCases {
            XCTAssertGreaterThan(skinType.vitaminDProductionMultiplier, 0.0)
        }
    }

    // MARK: - ModelingAssumptions Integration

    func testSunburnThresholdForKnownType() {
        let threshold = ModelingAssumptions.sunburnThreshold(for: .typeIII)
        XCTAssertEqual(threshold, FitzpatrickSkinType.typeIII.sunburnThresholdSED, accuracy: 0.001)
    }

    func testSunburnThresholdForNilTypeUsesDefault() {
        let threshold = ModelingAssumptions.sunburnThreshold(for: nil)
        XCTAssertEqual(threshold, ModelingAssumptions.defaultSunburnThresholdSED, accuracy: 0.001)
    }

    func testVitaminDMultiplierForNilTypeUsesReference() {
        let multiplier = ModelingAssumptions.vitaminDProductionMultiplier(for: nil)
        XCTAssertEqual(multiplier, 1.0, accuracy: 0.001)
    }

    // MARK: - Sun Exposure with Fitzpatrick Types

    func testDarkerSkinGetsLessVitaminDFromSun() {
        let gainTypeI = SunExposureCalculator.estimateVitaminDGain(
            uvIndex: 7.0, skinExposureFraction: 0.5, cloudCoverFraction: 0.0,
            durationMinutes: 15.0, skinType: .typeI
        )
        let gainTypeIII = SunExposureCalculator.estimateVitaminDGain(
            uvIndex: 7.0, skinExposureFraction: 0.5, cloudCoverFraction: 0.0,
            durationMinutes: 15.0, skinType: .typeIII
        )
        let gainTypeVI = SunExposureCalculator.estimateVitaminDGain(
            uvIndex: 7.0, skinExposureFraction: 0.5, cloudCoverFraction: 0.0,
            durationMinutes: 15.0, skinType: .typeVI
        )

        XCTAssertGreaterThan(gainTypeI, gainTypeIII)
        XCTAssertGreaterThan(gainTypeIII, gainTypeVI)
    }

    func testTypeVIProducesSignificantlyLessThanTypeI() {
        let gainI = SunExposureCalculator.estimateVitaminDGain(
            uvIndex: 7.0, skinExposureFraction: 0.5, cloudCoverFraction: 0.0,
            durationMinutes: 15.0, skinType: .typeI
        )
        let gainVI = SunExposureCalculator.estimateVitaminDGain(
            uvIndex: 7.0, skinExposureFraction: 0.5, cloudCoverFraction: 0.0,
            durationMinutes: 15.0, skinType: .typeVI
        )

        // Type VI should be roughly 1/6 of Type I
        let ratio = gainVI / gainI
        XCTAssertLessThan(ratio, 0.3, "Type VI should produce much less than Type I")
        XCTAssertGreaterThan(ratio, 0.05, "Type VI should still produce some vitamin D")
    }

    func testNilSkinTypeMatchesTypeII() {
        let gainNil = SunExposureCalculator.estimateVitaminDGain(
            uvIndex: 7.0, skinExposureFraction: 0.5, cloudCoverFraction: 0.0,
            durationMinutes: 15.0, skinType: nil
        )
        let gainTypeII = SunExposureCalculator.estimateVitaminDGain(
            uvIndex: 7.0, skinExposureFraction: 0.5, cloudCoverFraction: 0.0,
            durationMinutes: 15.0, skinType: .typeII
        )

        XCTAssertEqual(gainNil, gainTypeII, accuracy: 0.001)
    }

    // MARK: - UV Risk with Fitzpatrick Types

    func testDarkerSkinHasLongerSafeExposure() {
        let safeI = UVRiskCalculator.maxSafeExposureMinutes(uvIndex: 7.0, skinType: .typeI)!
        let safeIII = UVRiskCalculator.maxSafeExposureMinutes(uvIndex: 7.0, skinType: .typeIII)!
        let safeVI = UVRiskCalculator.maxSafeExposureMinutes(uvIndex: 7.0, skinType: .typeVI)!

        XCTAssertLessThan(safeI, safeIII)
        XCTAssertLessThan(safeIII, safeVI)
    }

    func testTypeVIHasFiveTimesSafeExposureOfTypeI() {
        let safeI = UVRiskCalculator.maxSafeExposureMinutes(uvIndex: 7.0, skinType: .typeI)!
        let safeVI = UVRiskCalculator.maxSafeExposureMinutes(uvIndex: 7.0, skinType: .typeVI)!

        // Type VI threshold (10 SED) is 5x Type I (2 SED)
        XCTAssertEqual(safeVI / safeI, 5.0, accuracy: 0.01)
    }

    func testOverexposureConsidersSkinType() {
        // At UV 7, Type I burns faster than Type VI
        let durationMinutes = 25.0

        let overexposedTypeI = UVRiskCalculator.isOverexposed(
            uvIndex: 7.0, durationMinutes: durationMinutes, skinType: .typeI
        )
        let overexposedTypeVI = UVRiskCalculator.isOverexposed(
            uvIndex: 7.0, durationMinutes: durationMinutes, skinType: .typeVI
        )

        XCTAssertTrue(overexposedTypeI, "Type I should be overexposed at 25 min UV 7")
        XCTAssertFalse(overexposedTypeVI, "Type VI should NOT be overexposed at 25 min UV 7")
    }

    func testExposurePercentageHigherForFairSkin() {
        let pctI = UVRiskCalculator.exposurePercentage(
            uvIndex: 7.0, durationMinutes: 10.0, skinType: .typeI
        )
        let pctVI = UVRiskCalculator.exposurePercentage(
            uvIndex: 7.0, durationMinutes: 10.0, skinType: .typeVI
        )

        XCTAssertGreaterThan(pctI, pctVI)
    }

    // MARK: - Gain Rate with Skin Type

    func testGainRateReducedForDarkerSkin() {
        let rateII = SunExposureCalculator.currentGainRate(
            uvIndex: 7.0, skinExposureFraction: 0.5, cloudCoverFraction: 0.0,
            elapsedMinutes: 5.0, skinType: .typeII
        )
        let rateV = SunExposureCalculator.currentGainRate(
            uvIndex: 7.0, skinExposureFraction: 0.5, cloudCoverFraction: 0.0,
            elapsedMinutes: 5.0, skinType: .typeV
        )

        XCTAssertGreaterThan(rateII, rateV)
    }

    // MARK: - Display Properties

    func testDisplayNames() {
        XCTAssertTrue(FitzpatrickSkinType.typeI.displayName.contains("Very Fair"))
        XCTAssertTrue(FitzpatrickSkinType.typeVI.displayName.contains("Dark"))
    }

    func testSunResponseDescriptions() {
        XCTAssertTrue(FitzpatrickSkinType.typeI.sunResponse.contains("Always burns"))
        XCTAssertTrue(FitzpatrickSkinType.typeVI.sunResponse.contains("Never burns"))
    }
}
