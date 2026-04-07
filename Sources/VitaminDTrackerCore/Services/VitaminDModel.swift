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

    /// Apply a complete daily update (decay + supplement).
    ///
    /// - Parameters:
    ///   - currentLevel: Current 25(OH)D level in ng/mL.
    ///   - plan: The active supplement plan.
    ///   - sunGain: Additional gain from sun exposure sessions (default 0).
    /// - Returns: A tuple of (newLevel, decayAmount, supplementGain).
    public static func applyDailyUpdate(
        currentLevel: Double,
        plan: SupplementPlan,
        sunGain: Double = 0.0
    ) -> (newLevel: Double, decayAmount: Double, supplementGain: Double) {
        let decay = dailyDecayAmount(currentLevel: currentLevel)
        let afterDecay = currentLevel - decay
        let suppGain = dailySupplementGain(plan: plan)
        let newLevel = afterDecay + suppGain + sunGain
        return (newLevel: max(newLevel, 0.0), decayAmount: decay, supplementGain: suppGain)
    }

    /// Calculate the steady-state level for a given supplement plan.
    /// At steady state, daily decay equals daily supplement gain.
    ///
    /// steadyState = supplementGain / decayRate
    ///
    /// - Parameter plan: The supplement plan.
    /// - Returns: Estimated steady-state 25(OH)D level in ng/mL.
    public static func steadyStateLevel(plan: SupplementPlan) -> Double {
        let gain = dailySupplementGain(plan: plan)
        let decayRate = ModelingAssumptions.dailyDecayRate
        guard decayRate > 0 else { return 0.0 }
        return gain / decayRate
    }

    /// Compute the estimated current level by replaying events from an anchor point.
    ///
    /// - Parameters:
    ///   - anchorLevel: The starting level (from lab test or baseline estimate).
    ///   - anchorDate: The date of the anchor.
    ///   - currentDate: The date to estimate for.
    ///   - supplementPlans: All supplement plans, sorted by effective date ascending.
    ///   - sunSessions: All completed sun sessions, sorted by start date ascending.
    /// - Returns: The estimated current level and a list of daily update events.
    public static func computeCurrentLevel(
        anchorLevel: Double,
        anchorDate: Date,
        currentDate: Date,
        supplementPlans: [SupplementPlan],
        sunSessions: [SunExposureSession]
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

            // Apply daily update
            let (newLevel, decayAmt, suppGain) = applyDailyUpdate(
                currentLevel: level,
                plan: activePlan ?? SupplementPlan(dailyDoseIU: 0, vitaminDType: .d3),
                sunGain: daySunGain
            )

            let event = DailyUpdateEvent(
                date: dayDate,
                previousLevel: level,
                decayAmount: decayAmt,
                supplementGain: suppGain,
                sunExposureGain: daySunGain,
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
