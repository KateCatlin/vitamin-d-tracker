import SwiftUI

/// Container view that manages the onboarding flow.
struct OnboardingContainerView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress indicator
                ProgressBar(
                    currentStep: viewModel.currentStep.rawValue,
                    totalSteps: OnboardingViewModel.OnboardingStep.allCases.count
                )
                .padding(.horizontal, 24)
                .padding(.top, 12)

                // Content
                TabView(selection: $viewModel.currentStep) {
                    WelcomeView()
                        .tag(OnboardingViewModel.OnboardingStep.welcome)

                    CitySelectionView(viewModel: viewModel)
                        .tag(OnboardingViewModel.OnboardingStep.citySelection)

                    TestResultInputView(viewModel: viewModel)
                        .tag(OnboardingViewModel.OnboardingStep.testResult)

                    SupplementInputView(viewModel: viewModel)
                        .tag(OnboardingViewModel.OnboardingStep.supplement)

                    DisclaimerView()
                        .tag(OnboardingViewModel.OnboardingStep.disclaimer)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: viewModel.currentStep)

                // Navigation buttons
                HStack(spacing: 16) {
                    if viewModel.currentStep != .welcome {
                        Button("Back") {
                            viewModel.previousStep()
                        }
                        .buttonStyle(OutlineButtonStyle())
                    }

                    Spacer()

                    Button(viewModel.currentStep == .disclaimer ? "Get Started" : "Next") {
                        if viewModel.currentStep == .disclaimer {
                            viewModel.completeOnboarding()
                        } else {
                            viewModel.nextStep()
                        }
                    }
                    .buttonStyle(SunButtonStyle())
                    .disabled(!viewModel.canProceed)
                    .opacity(viewModel.canProceed ? 1.0 : 0.5)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .onChange(of: viewModel.isComplete) { _, isComplete in
            if isComplete { onComplete() }
        }
    }
}

// MARK: - Progress Bar

struct ProgressBar: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Capsule()
                    .fill(step <= currentStep ? Color.sunYellow : Color.subtleDivider)
                    .frame(height: 4)
                    .animation(.easeInOut(duration: 0.3), value: currentStep)
            }
        }
    }
}
