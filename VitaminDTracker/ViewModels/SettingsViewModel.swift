import Foundation
import SwiftUI

#if canImport(Combine)
import Combine
#endif

/// View model for the settings screen.
@MainActor
class SettingsViewModel: ObservableObject {

    @Published var userProfile: UserProfile = UserProfile()
    @Published var currentSupplement: SupplementPlan?

    // New test result fields
    @Published var showTestResultSheet = false
    @Published var newTestValue = ""
    @Published var newTestUnit: VitaminDUnit = .ngPerML
    @Published var newTestDate = Date()

    // New supplement fields
    @Published var showSupplementSheet = false
    @Published var newDoseText = ""
    @Published var newVitaminDType: VitaminDType = .d3

    // City selection
    @Published var showCitySheet = false
    @Published var citySearchText = ""

    // Skin type
    @Published var showSkinTypeSheet = false

    // Model assumptions
    @Published var showModelAssumptions = false

    // Disclaimer
    @Published var showDisclaimer = false

    private let persistence = PersistenceManager.shared

    var filteredCities: [HomeLocation] {
        if citySearchText.isEmpty {
            return CityDatabase.cities
        }
        return CityDatabase.cities.filter {
            $0.cityName.localizedCaseInsensitiveContains(citySearchText)
        }
    }

    var supplementDisplayText: String {
        guard let plan = currentSupplement else { return "None" }
        if plan.dailyDoseIU == 0 { return "None" }
        return "\(Int(plan.dailyDoseIU)) IU \(plan.vitaminDType.rawValue)/day"
    }

    var skinTypeDisplayText: String {
        userProfile.skinType?.displayName ?? "Not set"
    }

    func loadData() {
        userProfile = persistence.userProfile
        currentSupplement = persistence.currentSupplementPlan
        if let plan = currentSupplement {
            newDoseText = plan.dailyDoseIU > 0 ? String(Int(plan.dailyDoseIU)) : ""
            newVitaminDType = plan.vitaminDType
        }
    }

    func updateCity(_ city: HomeLocation) {
        var profile = persistence.userProfile
        profile.homeLocation = city
        persistence.userProfile = profile
        userProfile = profile
        showCitySheet = false
    }

    func updateSkinType(_ skinType: FitzpatrickSkinType) {
        var profile = persistence.userProfile
        profile.skinType = skinType
        persistence.userProfile = profile
        userProfile = profile
        showSkinTypeSheet = false
    }

    func saveNewTestResult() {
        guard let value = Double(newTestValue), value > 0 else { return }

        let testResult = VitaminDTestResult(
            value: value,
            unit: newTestUnit,
            testDate: newTestDate
        )
        persistence.addTestResult(testResult)

        // Recalculate estimate from this new anchor
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

        AnalyticsService.shared.log(.labResultEntered)
        showTestResultSheet = false
        newTestValue = ""
    }

    func saveNewSupplement() {
        let dose = Double(newDoseText) ?? 0
        let plan = SupplementPlan(
            dailyDoseIU: dose,
            vitaminDType: newVitaminDType,
            effectiveDate: Date()
        )
        persistence.addSupplementPlan(plan)
        currentSupplement = plan

        AnalyticsService.shared.log(.supplementUpdated)
        showSupplementSheet = false
    }
}
