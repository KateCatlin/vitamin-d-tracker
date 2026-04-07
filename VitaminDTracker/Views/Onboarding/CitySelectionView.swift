import SwiftUI
import VitaminDTrackerCore

/// City selection step in onboarding.
struct CitySelectionView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("Where do you live?")
                .friendlyTitle()
                .padding(.top, 24)

            Text("Your home city helps estimate UV availability\nand baseline vitamin D levels.")
                .bodyText()
                .multilineTextAlignment(.center)

            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.textSecondary)
                TextField("Search cities...", text: $viewModel.citySearchText)
                    .font(.system(size: 16, design: .rounded))
            }
            .padding(12)
            .background(Color.skyBlueLight)
            .cornerRadius(12)
            .padding(.horizontal, 24)

            // City list
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.filteredCities, id: \.cityName) { city in
                        CityRow(
                            city: city,
                            isSelected: viewModel.selectedCity?.cityName == city.cityName
                        )
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.selectedCity = city
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }
}

struct CityRow: View {
    let city: HomeLocation
    let isSelected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(city.cityName)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.textPrimary)
                Text("Lat: \(String(format: "%.1f", city.latitude))°")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.textSecondary)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.sunOrange)
            }
        }
        .padding(12)
        .background(isSelected ? Color.sunYellowLight.opacity(0.4) : Color.cardBackground)
        .cornerRadius(10)
    }
}

#Preview {
    CitySelectionView(viewModel: OnboardingViewModel())
}
