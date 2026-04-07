import SwiftUI
import VitaminDTrackerCore

/// Test result input step in onboarding.
struct TestResultInputView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 24) {
            Text("Vitamin D Test Result")
                .friendlyTitle()
                .padding(.top, 24)

            Text("If you have a recent blood test result,\nenter it for a more accurate estimate.")
                .bodyText()
                .multilineTextAlignment(.center)

            // Toggle
            Toggle(isOn: $viewModel.hasTestResult.animation(.easeInOut)) {
                Text("I have a recent test result")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
            }
            .tint(.sunOrange)
            .padding(.horizontal, 32)

            if viewModel.hasTestResult {
                VStack(spacing: 16) {
                    // Value input
                    HStack(spacing: 12) {
                        TextField("Value", text: $viewModel.testValue)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .padding(12)
                            .background(Color.skyBlueLight)
                            .cornerRadius(12)

                        // Unit picker
                        Picker("Unit", selection: $viewModel.testUnit) {
                            ForEach(VitaminDUnit.allCases, id: \.self) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal, 32)

                    // Date picker
                    DatePicker(
                        "Test Date",
                        selection: $viewModel.testDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .padding(.horizontal, 32)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.skyBlue)

                    Text("No worries!")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.textPrimary)

                    Text("We'll estimate your baseline from\nyour location and the current season.")
                        .bodyText()
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
            }

            Spacer()
        }
    }
}

#Preview {
    TestResultInputView(viewModel: OnboardingViewModel())
}
