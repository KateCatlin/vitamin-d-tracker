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

    /// At the analytical steady state, decay must exactly equal supplement
    /// gain so the level does not move at all over many iterations.
    /// This proves the supplement is being credited (not just decay applied)
    /// and that the two formulas are correctly balanced.
    ///
    /// `backgroundGain` is left at its default 0 here on purpose: this test
    /// covers the *marginal* supplement dose-response in isolation.
    /// `testBackgroundGainHoldsBaselineFlat` does the analogous check for
    /// the background term.
    func testLevelIsFlatAtSteadyState() {
        let plan = SupplementPlan(dailyDoseIU: 3000, vitaminDType: .d3)
        let steady = VitaminDModel.steadyStateLevel(plan: plan) // ~30 ng/mL

        var level = steady
        for _ in 0..<200 {
            let (newLevel, decay, gain) = VitaminDModel.applyDailyUpdate(
                currentLevel: level,
                plan: plan
            )
            // At steady state, daily gain == daily decay, by construction.
            XCTAssertEqual(gain, decay, accuracy: 1e-9)
            level = newLevel
        }
        XCTAssertEqual(level, steady, accuracy: 1e-6,
                       "Level should not drift at all at steady state")
    }

    /// Starting above steady state should converge DOWN toward it (not overshoot,
    /// not drift to zero). This is the case the user observed: a D3 supplement is
    /// active but the displayed ng/mL still ticks down because the current level
    /// is above what that dose alone can sustain.
    func testConvergesDownToSteadyStateFromAbove() {
        let plan = SupplementPlan(dailyDoseIU: 2000, vitaminDType: .d3)
        let steady = VitaminDModel.steadyStateLevel(plan: plan) // ~20 ng/mL

        var level = steady + 15.0 // start at ~35 ng/mL
        var prev = level
        for _ in 0..<365 {
            let (newLevel, _, _) = VitaminDModel.applyDailyUpdate(currentLevel: level, plan: plan)
            // Strictly decreasing while above steady state, never crosses below.
            XCTAssertLessThan(newLevel, prev)
            XCTAssertGreaterThan(newLevel, steady)
            prev = level
            level = newLevel
        }
        // After ~1 year (≈17 half-lives) we should be effectively at steady state.
        XCTAssertEqual(level, steady, accuracy: 0.01)
    }

    /// Starting below steady state should converge UP — proves the supplement
    /// term is actually applied, not just decay.
    func testConvergesUpToSteadyStateFromBelow() {
        let plan = SupplementPlan(dailyDoseIU: 4000, vitaminDType: .d3)
        let steady = VitaminDModel.steadyStateLevel(plan: plan) // ~40 ng/mL

        var level = 5.0
        var prev = level
        for _ in 0..<365 {
            let (newLevel, _, _) = VitaminDModel.applyDailyUpdate(currentLevel: level, plan: plan)
            XCTAssertGreaterThan(newLevel, prev)
            XCTAssertLessThan(newLevel, steady)
            prev = level
            level = newLevel
        }
        XCTAssertEqual(level, steady, accuracy: 0.01)
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

    /// Mirror of the decay-only test: when an active supplement plan IS
    /// passed through computeCurrentLevel, every daily event records a
    /// non-zero supplementGain. Guards against a regression where the plan
    /// lookup returns nil and the model silently falls back to 0 IU.
    func testComputeCurrentLevelCreditsSupplementOnEveryDay() {
        let calendar = Calendar(identifier: .gregorian)
        let anchor = calendar.date(byAdding: .day, value: -10, to: Date())!
        let plan = SupplementPlan(
            dailyDoseIU: 2000,
            vitaminDType: .d3,
            effectiveDate: calendar.date(byAdding: .day, value: -30, to: Date())!
        )

        let expectedDailyGain = ModelingAssumptions.dailySupplementRise(
            doseIU: 2000, vitaminDType: .d3
        )

        let (level, events) = VitaminDModel.computeCurrentLevel(
            anchorLevel: 30.0,
            anchorDate: anchor,
            currentDate: Date(),
            supplementPlans: [plan],
            sunSessions: []
        )

        XCTAssertEqual(events.count, 10)
        for event in events {
            XCTAssertEqual(event.activeDoseIU, 2000, accuracy: 0.001)
            XCTAssertEqual(event.supplementGain, expectedDailyGain, accuracy: 1e-9,
                           "Supplement gain must be credited every day")
            XCTAssertEqual(
                event.newLevel,
                event.previousLevel - event.decayAmount + event.supplementGain
                    + event.sunExposureGain + event.backgroundGain,
                accuracy: 1e-9
            )
        }
        // Decay still wins because 30 > steady-state(2000 IU) ≈ 20.
        XCTAssertLessThan(level, 30.0)
        XCTAssertGreaterThan(level, VitaminDModel.steadyStateLevel(plan: plan))
    }

    // MARK: - Background Input (diet + incidental sun)

    /// Use the equator: latitude effect is constant and the seasonal effect's
    /// `latitudeScale` is 0 there, so `BaselineEstimator.estimateBaseline`
    /// returns an identical value every day. This lets the convergence test
    /// be exact even though the background term re-evaluates the baseline
    /// per replayed day.
    private static let equator = HomeLocation(
        cityName: "Equator", latitude: 0.0, longitude: 0.0
    )

    /// With a home location and no supplement, the level must converge to the
    /// location's baseline — not to zero. This is the user-reported bug: the
    /// model previously treated the supplement as the *only* input and slid
    /// toward `dose / 100` ng/mL as if the user lived in a dark box.
    func testBackgroundGainHoldsBaselineFlat() {
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.startOfDay(for: Date())
        let anchor = calendar.date(byAdding: .day, value: -200, to: now)!

        // Equatorial baseline is constant year-round (see comment on
        // `equator`), so the convergence target is a single number.
        let target = BaselineEstimator.estimateBaseline(location: Self.equator, date: anchor)

        let (level, events) = VitaminDModel.computeCurrentLevel(
            anchorLevel: target + 25.0,           // start well above
            anchorDate: anchor,
            currentDate: now,
            supplementPlans: [],
            sunSessions: [],
            homeLocation: Self.equator
        )

        XCTAssertEqual(events.count, 200)
        // Every event records a non-zero background term and a balanced ledger.
        for e in events {
            XCTAssertGreaterThan(e.backgroundGain, 0.0)
            XCTAssertEqual(
                e.newLevel,
                e.previousLevel - e.decayAmount + e.supplementGain
                    + e.sunExposureGain + e.backgroundGain,
                accuracy: 1e-9
            )
        }
        // After ~9.5 half-lives we're effectively at the floor — and the
        // floor is the *baseline*, not zero.
        XCTAssertEqual(level, target, accuracy: 0.05)
        XCTAssertGreaterThan(level, 5.0,
            "Background term must prevent the level collapsing toward zero")
    }

    /// Supplement effect is *marginal*: with the background term active the
    /// model converges to `baseline + steadyStateLevel(plan)`, not
    /// `steadyStateLevel(plan)` alone. The +10 ng/mL per 1000 IU rule from
    /// Heaney 2003 was always a rise above the subjects' existing level.
    func testBackgroundPlusSupplementIsAdditive() {
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.startOfDay(for: Date())
        let anchor = calendar.date(byAdding: .day, value: -300, to: now)!

        let plan = SupplementPlan(
            dailyDoseIU: 2000, vitaminDType: .d3,
            effectiveDate: calendar.date(byAdding: .day, value: -1, to: anchor)!
        )
        let baseline = BaselineEstimator.estimateBaseline(location: Self.equator, date: anchor)
        let suppOnly = VitaminDModel.steadyStateLevel(plan: plan) // ~20 ng/mL
        let target = baseline + suppOnly

        let (level, _) = VitaminDModel.computeCurrentLevel(
            anchorLevel: 5.0,
            anchorDate: anchor,
            currentDate: now,
            supplementPlans: [plan],
            sunSessions: [],
            homeLocation: Self.equator
        )

        XCTAssertEqual(level, target, accuracy: 0.1)
        XCTAssertGreaterThan(level, suppOnly + 5.0,
            "Background must lift the converged level well above the supplement-only ceiling")
    }

    /// Without a `homeLocation` no background gain is recorded — every
    /// event reads zero. Existing tests rely on this (they assert decay-only
    /// drift toward zero) so the legacy path stays intact.
    func testNoLocationMeansZeroBackgroundGain() {
        let calendar = Calendar(identifier: .gregorian)
        let anchor = calendar.date(byAdding: .day, value: -5, to: Date())!

        let (_, events) = VitaminDModel.computeCurrentLevel(
            anchorLevel: 30.0,
            anchorDate: anchor,
            currentDate: Date(),
            supplementPlans: [],
            sunSessions: []
        )

        XCTAssertEqual(events.count, 5)
        for e in events {
            XCTAssertEqual(e.backgroundGain, 0.0, accuracy: 1e-12)
        }
    }

    /// The baseline is re-evaluated for *each* replayed day so the background
    /// term tracks the seasonal curve. With Seattle (high latitude → strong
    /// seasonal swing) the term must be larger near the summer solstice than
    /// near the winter solstice when the same multi-month catch-up spans both.
    func testSeasonAwareBackgroundGainSummerVsWinter() {
        let calendar = Calendar(identifier: .gregorian)
        let seattle = HomeLocation(cityName: "Seattle", latitude: 47.6, longitude: -122.3)
        let anchor = calendar.date(from: DateComponents(year: 2025, month: 4, day: 1))!
        let end    = calendar.date(from: DateComponents(year: 2026, month: 1, day: 31))!

        let (_, events) = VitaminDModel.computeCurrentLevel(
            anchorLevel: 20.0,
            anchorDate: anchor,
            currentDate: end,
            supplementPlans: [],
            sunSessions: [],
            homeLocation: seattle
        )

        let near = { (e: DailyUpdateEvent, m: Int, d: Int) -> Bool in
            calendar.component(.month, from: e.date) == m
                && abs(calendar.component(.day, from: e.date) - d) <= 1
        }
        guard
            let summer = events.first(where: { near($0, 6, 21) }),
            let winter = events.first(where: { near($0, 12, 21) })
        else { return XCTFail("expected events spanning both solstices") }

        XCTAssertGreaterThan(summer.backgroundGain, winter.backgroundGain,
            "Seattle's background term should be larger in summer than in winter")
    }

    /// Skin type flows into the background term via `BaselineEstimator`.
    /// All else equal, type VI must produce a smaller daily background gain
    /// than type II.
    func testSkinTypeReducesBackgroundGainForDarkerSkin() {
        let calendar = Calendar(identifier: .gregorian)
        let anchor = calendar.date(byAdding: .day, value: -1, to: Date())!

        func bg(_ skin: FitzpatrickSkinType) -> Double {
            let (_, ev) = VitaminDModel.computeCurrentLevel(
                anchorLevel: 30.0,
                anchorDate: anchor,
                currentDate: Date(),
                supplementPlans: [],
                sunSessions: [],
                homeLocation: Self.equator,
                skinType: skin
            )
            return ev.first!.backgroundGain
        }

        XCTAssertGreaterThan(bg(.typeII), bg(.typeVI))
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
