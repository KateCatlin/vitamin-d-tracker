import SwiftUI

/// Supplement input step in onboarding.
struct SupplementInputView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 24) {
            Text("Daily Supplement")
                .friendlyTitle()
                .padding(.top, 24)

            Text("Do you take a daily vitamin D supplement?\nEnter your dose in IU (International Units).")
                .bodyText()
                .multilineTextAlignment(.center)

            VStack(spacing: 16) {
                // Dose input
                HStack {
                    TextField("0", text: $viewModel.dailyDoseText)
                        .keyboardType(.numberPad)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .padding(12)
                        .background(Color.skyBlueLight)
                        .cornerRadius(12)
                        .frame(maxWidth: 160)

                    Text("IU / day")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(.textSecondary)
                }

                // Common doses
                Text("Common doses")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.textSecondary)

                HStack(spacing: 10) {
                    ForEach([0, 400, 1000, 2000, 5000], id: \.self) { dose in
                        Button(dose == 0 ? "None" : "\(dose)") {
                            viewModel.dailyDoseText = dose == 0 ? "" : "\(dose)"
                        }
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            viewModel.dailyDoseText == (dose == 0 ? "" : "\(dose)")
                                ? Color.sunYellow.opacity(0.3)
                                : Color.cardBackground
                        )
                        .cornerRadius(8)
                    }
                }

                // D2 vs D3 selector
                VStack(spacing: 8) {
                    Text("Type")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.textSecondary)

                    Picker("Vitamin D Type", selection: $viewModel.vitaminDType) {
                        ForEach(VitaminDType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 200)

                    Text(viewModel.vitaminDType == .d3
                         ? "D3 is more effective at raising blood levels"
                         : "D2 is about 50% as effective as D3")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.textSecondary)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }
}

#Preview {
    SupplementInputView(viewModel: OnboardingViewModel())
}
