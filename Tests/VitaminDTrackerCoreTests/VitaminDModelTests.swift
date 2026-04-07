import XCTest
@testable import VitaminDTrackerCore

final class VitaminDModelTests: XCTestCase {

    // MARK: - Decay Logic

    func testDailyDecayReducesLevel() {
        let initial = 30.0
        let afterDecay = VitaminDModel.applyDailyDecay(currentLevel: initial)
        XCTAssertLessThan(afterDecay, initial)
        XCTAssertGreaterThan(afterDecay, 0.0)
    }

    func testDailyDecayAmount() {
        let level = 30.0
        let decay = VitaminDModel.dailyDecayAmount(currentLevel: level)
        XCTAssertGreaterThan(decay, 0.0)
        XCTAssertLessThan(decay, level)
        // Decay should be approximately 3.25% of level (from 21-day half-life)
        let expectedDecayRate = 1.0 - pow(2.0, -1.0 / 21.0)
        XCTAssertEqual(decay, level * expectedDecayRate, accuracy: 0.001)
    }

    func testDecayOverHalfLifeReducesByHalf() {
        var level = 40.0
        for _ in 0..<21 {
            level = VitaminDModel.applyDailyDecay(currentLevel: level)
        }
        // After 21 days (half-life), level should be approximately half
        XCTAssertEqual(level, 20.0, accuracy: 1.0)
    }

    func testDecayToZero() {
        var level = 10.0
        for _ in 0..<365 {
            level = VitaminDModel.applyDailyDecay(currentLevel: level)
        }
        // After a year of decay with no input, should be near zero
        XCTAssertLessThan(level, 0.01)
    }

    // MARK: - Supplement Effect

    func testDailySupplementGainD3() {
        let plan = SupplementPlan(dailyDoseIU: 1000, vitaminDType: .d3)
        let gain = VitaminDModel.dailySupplementGain(plan: plan)
        XCTAssertGreaterThan(gain, 0.0)
    }

    func testDailySupplementGainD2IsLessThanD3() {
        let planD3 = SupplementPlan(dailyDoseIU: 1000, vitaminDType: .d3)
        let planD2 = SupplementPlan(dailyDoseIU: 1000, vitaminDType: .d2)

        let gainD3 = VitaminDModel.dailySupplementGain(plan: planD3)
        let gainD2 = VitaminDModel.dailySupplementGain(plan: planD2)

        XCTAssertGreaterThan(gainD3, gainD2)
        // D2 should be 50% as effective as D3
        XCTAssertEqual(gainD2, gainD3 * 0.5, accuracy: 0.001)
    }

    func testHigherDoseGivesMoreGain() {
        let plan1000 = SupplementPlan(dailyDoseIU: 1000, vitaminDType: .d3)
        let plan2000 = SupplementPlan(dailyDoseIU: 2000, vitaminDType: .d3)

        let gain1000 = VitaminDModel.dailySupplementGain(plan: plan1000)
        let gain2000 = VitaminDModel.dailySupplementGain(plan: plan2000)

        XCTAssertEqual(gain2000, gain1000 * 2.0, accuracy: 0.001)
    }

    func testZeroDoseGivesNoGain() {
        let plan = SupplementPlan(dailyDoseIU: 0, vitaminDType: .d3)
        let gain = VitaminDModel.dailySupplementGain(plan: plan)
        XCTAssertEqual(gain, 0.0, accuracy: 0.001)
    }

    // MARK: - Steady State

    func testSteadyStateLevelD3_1000IU() {
        let plan = SupplementPlan(dailyDoseIU: 1000, vitaminDType: .d3)
        let steadyState = VitaminDModel.steadyStateLevel(plan: plan)
        // 1000 IU/day D3 should give ~10 ng/mL at steady state
        XCTAssertEqual(steadyState, 10.0, accuracy: 0.5)
    }

    func testSteadyStateLevelD2IsLowerThanD3() {
        let planD3 = SupplementPlan(dailyDoseIU: 2000, vitaminDType: .d3)
        let planD2 = SupplementPlan(dailyDoseIU: 2000, vitaminDType: .d2)

        let ssD3 = VitaminDModel.steadyStateLevel(plan: planD3)
        let ssD2 = VitaminDModel.steadyStateLevel(plan: planD2)

        XCTAssertGreaterThan(ssD3, ssD2)
    }

    // MARK: - Daily Update

    func testDailyUpdateAppliesDecayAndSupplement() {
        let plan = SupplementPlan(dailyDoseIU: 1000, vitaminDType: .d3)
        let (newLevel, decay, suppGain) = VitaminDModel.applyDailyUpdate(
            currentLevel: 30.0,
            plan: plan
        )

        XCTAssertGreaterThan(decay, 0.0)
        XCTAssertGreaterThan(suppGain, 0.0)
        XCTAssertEqual(newLevel, 30.0 - decay + suppGain, accuracy: 0.001)
    }

    func testDailyUpdateWithSunGain() {
        let plan = SupplementPlan(dailyDoseIU: 1000, vitaminDType: .d3)
        let sunGain = 2.0

        let (newLevel, decay, suppGain) = VitaminDModel.applyDailyUpdate(
            currentLevel: 30.0,
            plan: plan,
            sunGain: sunGain
        )

        XCTAssertEqual(newLevel, 30.0 - decay + suppGain + sunGain, accuracy: 0.001)
    }

    func testDailyUpdateNeverGoesNegative() {
        let plan = SupplementPlan(dailyDoseIU: 0, vitaminDType: .d3)
        let (newLevel, _, _) = VitaminDModel.applyDailyUpdate(
            currentLevel: 0.01,
            plan: plan
        )
        XCTAssertGreaterThanOrEqual(newLevel, 0.0)
    }

    // MARK: - Multi-day Computation

    func testComputeCurrentLevelSameDay() {
        let now = Date()
        let (level, events) = VitaminDModel.computeCurrentLevel(
            anchorLevel: 30.0,
            anchorDate: now,
            currentDate: now,
            supplementPlans: [],
            sunSessions: []
        )

        XCTAssertEqual(level, 30.0, accuracy: 0.001)
        XCTAssertTrue(events.isEmpty)
    }

    func testComputeCurrentLevelMultipleDays() {
        let calendar = Calendar(identifier: .gregorian)
        let anchor = calendar.date(byAdding: .day, value: -7, to: Date())!
        let plan = SupplementPlan(
            dailyDoseIU: 1000,
            vitaminDType: .d3,
            effectiveDate: calendar.date(byAdding: .day, value: -30, to: Date())!
        )

        let (level, events) = VitaminDModel.computeCurrentLevel(
            anchorLevel: 30.0,
            anchorDate: anchor,
            currentDate: Date(),
            supplementPlans: [plan],
            sunSessions: []
        )

        XCTAssertEqual(events.count, 7)
        XCTAssertNotEqual(level, 30.0)
    }

    func testComputeCurrentLevelDecayOnlyNoSupplement() {
        let calendar = Calendar(identifier: .gregorian)
        let anchor = calendar.date(byAdding: .day, value: -10, to: Date())!

        let (level, events) = VitaminDModel.computeCurrentLevel(
            anchorLevel: 40.0,
            anchorDate: anchor,
            currentDate: Date(),
            supplementPlans: [],
            sunSessions: []
        )

        XCTAssertEqual(events.count, 10)
        XCTAssertLessThan(level, 40.0)
        // All events should show zero supplement gain
        for event in events {
            XCTAssertEqual(event.supplementGain, 0.0, accuracy: 0.001)
        }
    }

    // MARK: - Forward-only Supplement Changes

    func testSupplementChangeIsForwardOnly() {
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.startOfDay(for: Date())
        let anchor = calendar.date(byAdding: .day, value: -10, to: now)!

        // Plan 1: 1000 IU from 30 days ago
        let plan1 = SupplementPlan(
            dailyDoseIU: 1000,
            vitaminDType: .d3,
            effectiveDate: calendar.date(byAdding: .day, value: -30, to: now)!
        )
        // Plan 2: 2000 IU effective 5 days after anchor (= 5 days ago)
        // anchor + 5 days is the effective date; events for that day and after use plan2
        let plan2EffectiveDate = calendar.date(byAdding: .day, value: 5, to: anchor)!
        let plan2 = SupplementPlan(
            dailyDoseIU: 2000,
            vitaminDType: .d3,
            effectiveDate: plan2EffectiveDate
        )

        let (_, events) = VitaminDModel.computeCurrentLevel(
            anchorLevel: 30.0,
            anchorDate: anchor,
            currentDate: now,
            supplementPlans: [plan1, plan2],
            sunSessions: []
        )

        XCTAssertEqual(events.count, 10)

        // First 4 events (days 1-4 after anchor) should use 1000 IU plan
        // Plan2 becomes effective on day 5 (anchor + 5)
        for i in 0..<4 {
            XCTAssertEqual(events[i].activeDoseIU, 1000.0, accuracy: 0.001,
                          "Event \(i) should use plan1 (1000 IU)")
        }
        // Day 5 onward (events 4-9) should use 2000 IU plan
        for i in 4..<10 {
            XCTAssertEqual(events[i].activeDoseIU, 2000.0, accuracy: 0.001,
                          "Event \(i) should use plan2 (2000 IU)")
        }
    }
}
