import Foundation
import SwiftUI

#if canImport(Combine)
import Combine
#endif

/// View model for the onboarding flow.
@MainActor
class OnboardingViewModel: ObservableObject {

    // MARK: - Onboarding State

    enum OnboardingStep: Int, CaseIterable {
        case welcome = 0
        case citySelection = 1
        case skinType = 2
        case testResult = 3
        case supplement = 4
        case disclaimer = 5
    }

    @Published var currentStep: OnboardingStep = .welcome
    @Published var isComplete = false

    // MARK: - City Selection

    @Published var selectedCity: HomeLocation?
    @Published var citySearchText = ""

    var filteredCities: [HomeLocation] {
        if citySearchText.isEmpty {
            return CityDatabase.cities
        }
        return CityDatabase.cities.filter {
            $0.cityName.localizedCaseInsensitiveContains(citySearchText)
        }
    }

    // MARK: - Skin Type

    @Published var selectedSkinType: FitzpatrickSkinType?

    // MARK: - Test Result

    @Published var hasTestResult = false
    @Published var testValue = ""
    @Published var testUnit: VitaminDUnit = .ngPerML
    @Published var testDate = Date()

    // MARK: - Supplement

    @Published var dailyDoseText = ""
    @Published var vitaminDType: VitaminDType = .d3

    // MARK: - Navigation

    func nextStep() {
        guard let next = OnboardingStep(rawValue: currentStep.rawValue + 1) else {
            completeOnboarding()
            return
        }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = next
        }
    }

    func previousStep() {
        guard let prev = OnboardingStep(rawValue: currentStep.rawValue - 1) else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = prev
        }
    }

    var canProceed: Bool {
        switch currentStep {
        case .welcome: return true
        case .citySelection: return selectedCity != nil
        case .skinType: return selectedSkinType != nil
        case .testResult: return !hasTestResult || (!testValue.isEmpty && Double(testValue) != nil)
        case .supplement: return true
        case .disclaimer: return true
        }
    }

    // MARK: - Complete Onboarding

    func completeOnboarding() {
        guard let city = selectedCity else { return }

        let persistence = PersistenceManager.shared
        let analytics = AnalyticsService.shared

        // Save user profile
        var profile = persistence.userProfile
        profile.homeLocation = city
        profile.skinType = selectedSkinType
        profile.hasCompletedOnboarding = true
        profile.disclaimerAccepted = true
        profile.disclaimerAcceptedDate = Date()
        persistence.userProfile = profile

        // Save supplement plan
        let dose = Double(dailyDoseText) ?? 0
        let plan = SupplementPlan(
            dailyDoseIU: dose,
            vitaminDType: vitaminDType,
            effectiveDate: Date()
        )
        persistence.addSupplementPlan(plan)

        // Handle test result or create baseline estimate
        if hasTestResult, let value = Double(testValue) {
            let testResult = VitaminDTestResult(
                value: value,
                unit: testUnit,
                testDate: testDate
            )
            persistence.addTestResult(testResult)

            let (estimate, events) = DailyUpdateService.applyLabResult(
                testResult: testResult,
                currentDate: Date(),
                supplementPlans: persistence.supplementPlans,
                sunSessions: persistence.sunSessions
            )
            persistence.currentEstimate = estimate
            if !events.isEmpty {
                persistence.addDailyEvents(events)
            }

            analytics.log(.labResultEntered)
        } else {
            let estimate = DailyUpdateService.createBaselineEstimate(
                location: city,
                date: Date()
            )
            persistence.currentEstimate = estimate
        }

        persistence.lastDailyUpdateDate = Date()
        analytics.log(.onboardingCompleted)

        withAnimation(.easeInOut(duration: 0.3)) {
            isComplete = true
        }
    }
}
