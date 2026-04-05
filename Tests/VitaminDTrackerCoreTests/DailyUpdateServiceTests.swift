import XCTest
@testable import VitaminDTrackerCore

final class DailyUpdateServiceTests: XCTestCase {

    // MARK: - Catch-up Logic

    func testCatchUpSameDayNoEvents() {
        let now = Date()
        let estimate = VitaminDStateEstimate(
            estimatedLevel: 30.0,
            source: .labMeasurement,
            confidence: .high,
            date: now
        )

        let (newEstimate, events) = DailyUpdateService.catchUp(
            lastEstimate: estimate,
            currentDate: now,
            supplementPlans: [],
            sunSessions: []
        )

        XCTAssertTrue(events.isEmpty)
        XCTAssertEqual(newEstimate.estimatedLevel, estimate.estimatedLevel, accuracy: 0.001)
    }

    func testCatchUpMultipleDays() {
        let calendar = Calendar(identifier: .gregorian)
        let fiveDaysAgo = calendar.date(byAdding: .day, value: -5, to: Date())!

        let estimate = VitaminDStateEstimate(
            estimatedLevel: 30.0,
            source: .labMeasurement,
            confidence: .high,
            date: fiveDaysAgo
        )

        let plan = SupplementPlan(
            dailyDoseIU: 1000,
            vitaminDType: .d3,
            effectiveDate: calendar.date(byAdding: .day, value: -30, to: Date())!
        )

        let (newEstimate, events) = DailyUpdateService.catchUp(
            lastEstimate: estimate,
            currentDate: Date(),
            supplementPlans: [plan],
            sunSessions: []
        )

        XCTAssertEqual(events.count, 5)
        XCTAssertNotEqual(newEstimate.estimatedLevel, 30.0)
        XCTAssertEqual(newEstimate.source, .modelEstimate)
    }

    func testCatchUpWithLabAnchorHasModerateConfidence() {
        let calendar = Calendar(identifier: .gregorian)
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: Date())!

        let estimate = VitaminDStateEstimate(
            estimatedLevel: 30.0,
            source: .labMeasurement,
            confidence: .high,
            date: threeDaysAgo
        )

        let (newEstimate, _) = DailyUpdateService.catchUp(
            lastEstimate: estimate,
            currentDate: Date(),
            supplementPlans: [],
            sunSessions: []
        )

        // When the anchor is a lab measurement, the catch-up should have moderate confidence
        XCTAssertEqual(newEstimate.confidence, .moderate)
    }

    func testCatchUpDecayOnly() {
        let calendar = Calendar(identifier: .gregorian)
        let tenDaysAgo = calendar.date(byAdding: .day, value: -10, to: Date())!

        let estimate = VitaminDStateEstimate(
            estimatedLevel: 40.0,
            source: .geographicEstimate,
            confidence: .low,
            date: tenDaysAgo
        )

        let (newEstimate, events) = DailyUpdateService.catchUp(
            lastEstimate: estimate,
            currentDate: Date(),
            supplementPlans: [],
            sunSessions: []
        )

        XCTAssertEqual(events.count, 10)
        XCTAssertLessThan(newEstimate.estimatedLevel, 40.0)
        // All events should have zero supplement gain
        for event in events {
            XCTAssertEqual(event.supplementGain, 0.0, accuracy: 0.001)
        }
    }

    // MARK: - Lab Result Application

    func testApplyLabResultSameDay() {
        let testResult = VitaminDTestResult(
            value: 35.0,
            unit: .ngPerML,
            testDate: Date()
        )

        let (newEstimate, events) = DailyUpdateService.applyLabResult(
            testResult: testResult,
            currentDate: Date(),
            supplementPlans: [],
            sunSessions: []
        )

        XCTAssertEqual(newEstimate.estimatedLevel, 35.0, accuracy: 0.001)
        XCTAssertEqual(newEstimate.source, .labMeasurement)
        XCTAssertEqual(newEstimate.confidence, .high)
        XCTAssertTrue(events.isEmpty)
    }

    func testApplyLabResultFromPast() {
        let calendar = Calendar(identifier: .gregorian)
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date())!

        let testResult = VitaminDTestResult(
            value: 35.0,
            unit: .ngPerML,
            testDate: sevenDaysAgo
        )

        let plan = SupplementPlan(
            dailyDoseIU: 1000,
            vitaminDType: .d3,
            effectiveDate: calendar.date(byAdding: .day, value: -30, to: Date())!
        )

        let (newEstimate, events) = DailyUpdateService.applyLabResult(
            testResult: testResult,
            currentDate: Date(),
            supplementPlans: [plan],
            sunSessions: []
        )

        XCTAssertEqual(events.count, 7)
        XCTAssertNotEqual(newEstimate.estimatedLevel, 35.0) // Should have progressed
        XCTAssertEqual(newEstimate.source, .modelEstimate)
        XCTAssertEqual(newEstimate.confidence, .high) // Within 14 days of lab
    }

    func testApplyLabResultNmolL() {
        // 74.88 nmol/L = 30 ng/mL
        let testResult = VitaminDTestResult(
            value: 74.88,
            unit: .nmolPerL,
            testDate: Date()
        )

        let (newEstimate, _) = DailyUpdateService.applyLabResult(
            testResult: testResult,
            currentDate: Date(),
            supplementPlans: [],
            sunSessions: []
        )

        XCTAssertEqual(newEstimate.estimatedLevel, 30.0, accuracy: 0.1)
    }

    func testApplyOldLabResultLosesHighConfidence() {
        let calendar = Calendar(identifier: .gregorian)
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date())!

        let testResult = VitaminDTestResult(
            value: 35.0,
            unit: .ngPerML,
            testDate: thirtyDaysAgo
        )

        let (newEstimate, events) = DailyUpdateService.applyLabResult(
            testResult: testResult,
            currentDate: Date(),
            supplementPlans: [],
            sunSessions: []
        )

        XCTAssertEqual(events.count, 30)
        // After 30 days, confidence drops to moderate
        XCTAssertEqual(newEstimate.confidence, .moderate)
    }

    // MARK: - Baseline Estimation

    func testCreateBaselineEstimate() {
        let location = HomeLocation(cityName: "Los Angeles", latitude: 34.05, longitude: -118.24)
        let estimate = DailyUpdateService.createBaselineEstimate(location: location)

        XCTAssertEqual(estimate.source, .geographicEstimate)
        XCTAssertEqual(estimate.confidence, .low)
        XCTAssertGreaterThanOrEqual(estimate.estimatedLevel, 5.0)
        XCTAssertLessThanOrEqual(estimate.estimatedLevel, 60.0)
    }

    // MARK: - Overdue Catch-up Correctness

    func testCatchUpProducesSameResultRegardlessOfTiming() {
        let calendar = Calendar(identifier: .gregorian)
        let tenDaysAgo = calendar.date(byAdding: .day, value: -10, to: Date())!

        let estimate = VitaminDStateEstimate(
            estimatedLevel: 30.0,
            source: .labMeasurement,
            confidence: .high,
            date: tenDaysAgo
        )

        let plan = SupplementPlan(
            dailyDoseIU: 1000,
            vitaminDType: .d3,
            effectiveDate: calendar.date(byAdding: .day, value: -30, to: Date())!
        )

        // Simulate catching up all at once
        let (allAtOnce, _) = DailyUpdateService.catchUp(
            lastEstimate: estimate,
            currentDate: Date(),
            supplementPlans: [plan],
            sunSessions: []
        )

        // Simulate catching up day by day
        var currentEstimate = estimate
        for dayOffset in 1...10 {
            let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: tenDaysAgo)!
            let (updated, _) = DailyUpdateService.catchUp(
                lastEstimate: currentEstimate,
                currentDate: dayDate,
                supplementPlans: [plan],
                sunSessions: []
            )
            currentEstimate = updated
        }

        // Both approaches should yield the same result
        XCTAssertEqual(
            allAtOnce.estimatedLevel,
            currentEstimate.estimatedLevel,
            accuracy: 0.01
        )
    }
}
