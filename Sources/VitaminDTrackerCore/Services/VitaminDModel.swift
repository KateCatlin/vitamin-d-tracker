import Foundation

/// Core vitamin D estimation model.
///
/// This service computes the estimated current vitamin D level by:
/// 1. Starting from the most recent anchor (lab test or geographic baseline)
/// 2. Applying daily decay
/// 3. Adding daily supplement contribution
/// 4. Adding sun exposure session contributions
///
/// All levels are in ng/mL (25-hydroxyvitamin D).
///
/// See MODELING.md for the complete scientific methodology.
public struct VitaminDModel {

    /// Apply one day of decay to a vitamin D level.
    ///
    /// Uses first-order kinetics: level *= (1 - dailyDecayRate)
    ///
    /// - Parameter currentLevel: Current 25(OH)D level in ng/mL.
    /// - Returns: Level after one day of decay.
    public static func applyDailyDecay(currentLevel: Double) -> Double {
        let decayRate = ModelingAssumptions.dailyDecayRate
        return currentLevel * (1.0 - decayRate)
    }

    /// Calculate the amount lost to decay in one day.
    public static func dailyDecayAmount(currentLevel: Double) -> Double {
        return currentLevel * ModelingAssumptions.dailyDecayRate
    }

    /// Apply one day of supplement contribution.
    ///
    /// - Parameters:
    ///   - currentLevel: Current 25(OH)D level in ng/mL.
    ///   - plan: The active supplement plan.
    /// - Returns: Level after applying one day of supplementation.
    public static func applyDailySupplement(
        currentLevel: Double,
        plan: SupplementPlan
    ) -> Double {
        let gain = ModelingAssumptions.dailySupplementRise(
            doseIU: plan.dailyDoseIU,
            vitaminDType: plan.vitaminDType
        )
        return currentLevel + gain
    }

    /// Calculate the daily supplement gain in ng/mL.
    public static func dailySupplementGain(plan: SupplementPlan) -> Double {
        return ModelingAssumptions.dailySupplementRise(
            doseIU: plan.dailyDoseIU,
            vitaminDType: plan.vitaminDType
        )
    }

    /// Apply a complete daily update (decay + supplement + sun + background).
    ///
    /// - Parameters:
    ///   - currentLevel: Current 25(OH)D level in ng/mL.
    ///   - plan: The active supplement plan.
    ///   - sunGain: Additional gain from explicitly tracked sun sessions (default 0).
    ///   - backgroundGain: Daily gain from diet + incidental sun the user never
    ///     logs (default 0). See `ModelingAssumptions.dailyBackgroundRise` for
    ///     why this term exists. Pass 0 to recover the legacy supplement-only
    ///     behaviour, which is what the unit tests for the supplement dose-
    ///     response do.
    /// - Returns: A tuple of (newLevel, decayAmount, supplementGain).
    public static func applyDailyUpdate(
        currentLevel: Double,
        plan: SupplementPlan,
        sunGain: Double = 0.0,
        backgroundGain: Double = 0.0
    ) -> (newLevel: Double, decayAmount: Double, supplementGain: Double) {
        let decay = dailyDecayAmount(currentLevel: currentLevel)
        let afterDecay = currentLevel - decay
        let suppGain = dailySupplementGain(plan: plan)
        let newLevel = afterDecay + suppGain + sunGain + backgroundGain
        return (newLevel: max(newLevel, 0.0), decayAmount: decay, supplementGain: suppGain)
    }

    /// Calculate the steady-state level for a given supplement plan.
    /// At steady state, daily decay equals daily supplement gain.
    ///
    /// steadyState = supplementGain / decayRate
    ///
    /// **Note:** this is the *marginal* contribution of the supplement alone —
    /// the amount the supplement adds on top of whatever baseline the user
    /// would otherwise have. With the background term active in
    /// `computeCurrentLevel`, the model converges toward
    /// `baseline + steadyStateLevel(plan)`, not `steadyStateLevel(plan)` alone.
    ///
    /// - Parameter plan: The supplement plan.
    /// - Returns: Marginal steady-state increment in ng/mL.
    public static func steadyStateLevel(plan: SupplementPlan) -> Double {
        let gain = dailySupplementGain(plan: plan)
        let decayRate = ModelingAssumptions.dailyDecayRate
        guard decayRate > 0 else { return 0.0 }
        return gain / decayRate
    }

    /// Compute the estimated current level by replaying events from an anchor point.
    ///
    /// **Background term.** When `homeLocation` is provided, each replayed day
    /// also receives a small "background" gain representing diet (~190 IU/day
    /// per NHANES) plus incidental sun exposure that the user never tracks.
    /// Without it, the supplement dose-response — which is a *marginal* effect
    /// in the literature — gets misinterpreted as an absolute, and the model
    /// drifts toward `dose / 100` ng/mL as if the user lived in a dark box.
    ///
    /// The background term is sized so that with no supplement and no tracked
    /// sun the level converges to whatever `BaselineEstimator.estimateBaseline`
    /// predicts for that location/date/skin type. The baseline is re-evaluated
    /// for each replayed day, so the user gently drifts down through their
    /// city's winter and back up through summer. The supplement effect remains
    /// exactly +10 ng/mL per 1000 IU D3, but now correctly stacked on top.
    ///
    /// Tracked sun sessions are *additional* to the background term: the
    /// baseline encodes typical incidental exposure (walk to the car, errands),
    /// not deliberate sunbathing, so a logged 30-minute session is genuinely
    /// additive.
    ///
    /// - Parameters:
    ///   - anchorLevel: The starting level (from lab test or baseline estimate).
    ///   - anchorDate: The date of the anchor.
    ///   - currentDate: The date to estimate for.
    ///   - supplementPlans: All supplement plans, sorted by effective date ascending.
    ///   - sunSessions: All completed sun sessions, sorted by start date ascending.
    ///   - homeLocation: User's home location. When `nil`, no background term
    ///     is applied (legacy supplement-only behaviour).
    ///   - skinType: Fitzpatrick skin type. Adjusts the incidental-sun portion
    ///     of the background baseline. When `nil`, fair-skin reference is used.
    /// - Returns: The estimated current level and a list of daily update events.
    public static func computeCurrentLevel(
        anchorLevel: Double,
        anchorDate: Date,
        currentDate: Date,
        supplementPlans: [SupplementPlan],
        sunSessions: [SunExposureSession],
        homeLocation: HomeLocation? = nil,
        skinType: FitzpatrickSkinType? = nil
    ) -> (estimatedLevel: Double, events: [DailyUpdateEvent]) {
        let calendar = Calendar(identifier: .gregorian)
        let startOfAnchor = calendar.startOfDay(for: anchorDate)
        let startOfCurrent = calendar.startOfDay(for: currentDate)

        let daysBetween = calendar.dateComponents([.day], from: startOfAnchor, to: startOfCurrent).day ?? 0

        guard daysBetween > 0 else {
            return (estimatedLevel: anchorLevel, events: [])
        }

        var level = anchorLevel
        var events: [DailyUpdateEvent] = []

        // Sort plans by date for lookup
        let sortedPlans = supplementPlans.sorted { $0.effectiveDate < $1.effectiveDate }

        for dayOffset in 1...daysBetween {
            guard let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: startOfAnchor) else {
                continue
            }

            // Find active supplement plan for this day
            let activePlan = findActivePlan(for: dayDate, plans: sortedPlans)

            // Find sun sessions completed on this day
            let daySunGain = sunGainForDay(date: dayDate, sessions: sunSessions, calendar: calendar)

            // Background gain: re-evaluate the baseline for *this* calendar day
            // so the term drifts with the season. With homeLocation == nil this
            // is 0 and we get the legacy supplement-only behaviour.
            let dayBackgroundGain: Double
            if let location = homeLocation {
                let dayBaseline = BaselineEstimator.estimateBaseline(
                    location: location,
                    date: dayDate,
                    skinType: skinType
                )
                dayBackgroundGain = ModelingAssumptions.dailyBackgroundRise(forBaselineNgML: dayBaseline)
            } else {
                dayBackgroundGain = 0.0
            }

            // Apply daily update
            let (newLevel, decayAmt, suppGain) = applyDailyUpdate(
                currentLevel: level,
                plan: activePlan ?? SupplementPlan(dailyDoseIU: 0, vitaminDType: .d3),
                sunGain: daySunGain,
                backgroundGain: dayBackgroundGain
            )

            let event = DailyUpdateEvent(
                date: dayDate,
                previousLevel: level,
                decayAmount: decayAmt,
                supplementGain: suppGain,
                sunExposureGain: daySunGain,
                backgroundGain: dayBackgroundGain,
                newLevel: newLevel,
                activeDoseIU: activePlan?.dailyDoseIU ?? 0,
                activeVitaminDType: activePlan?.vitaminDType ?? .d3
            )

            events.append(event)
            level = newLevel
        }

        return (estimatedLevel: level, events: events)
    }

    /// Find the active supplement plan for a given date.
    /// The active plan is the most recent one with an effective date on or before the given date.
    static func findActivePlan(for date: Date, plans: [SupplementPlan]) -> SupplementPlan? {
        let calendar = Calendar(identifier: .gregorian)
        return plans.last { plan in
            calendar.startOfDay(for: plan.effectiveDate) <= calendar.startOfDay(for: date)
        }
    }

    /// Sum the vitamin D gain from sun sessions completed on a specific day.
    static func sunGainForDay(
        date: Date,
        sessions: [SunExposureSession],
        calendar: Calendar
    ) -> Double {
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return 0.0
        }

        return sessions
            .filter { session in
                session.isCompleted &&
                session.startTime >= startOfDay &&
                session.startTime < endOfDay
            }
            .reduce(0.0) { sum, session in
                sum + session.estimatedVitaminDGain
            }
    }
}
