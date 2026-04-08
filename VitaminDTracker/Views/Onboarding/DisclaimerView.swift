import SwiftUI
import VitaminDTrackerCore

/// Disclaimer and explanation view — final onboarding step.
struct DisclaimerView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("How It Works")
                    .friendlyTitle()
                    .padding(.top, 24)

                // Explanation
                VStack(alignment: .leading, spacing: 16) {
                    ExplanationRow(
                        icon: "flask.fill",
                        title: "Lab Results",
                        text: "When you enter a blood test result, it becomes the most trusted data point. The app adjusts your estimate from that anchor."
                    )
                    ExplanationRow(
                        icon: "arrow.down.right",
                        title: "Natural Decay",
                        text: "Vitamin D has a half-life of about 3 weeks. Your level naturally decreases over time without input."
                    )
                    ExplanationRow(
                        icon: "fork.knife",
                        title: "Background Input",
                        text: "Diet and incidental everyday sun keep your level near a baseline that depends on your city, the season, and your skin type — even before any supplement."
                    )
                    ExplanationRow(
                        icon: "pills.fill",
                        title: "Supplements",
                        text: "Daily supplements add about 10 ng/mL per 1000 IU of D3 on top of that baseline. D3 is more effective than D2 per IU."
                    )
                    ExplanationRow(
                        icon: "sun.max.fill",
                        title: "Sun Exposure",
                        text: "Tracked sun sessions add to your estimate based on UV conditions, skin exposure, and duration."
                    )
                }
                .softCard()
                .padding(.horizontal, 24)

                // Disclaimer
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.sunOrange)
                        Text("Important Disclaimer")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.textPrimary)
                    }

                    Group {
                        DisclaimerItem(text: "This app provides rough estimates only.")
                        DisclaimerItem(text: "This is NOT medical advice.")
                        DisclaimerItem(text: "This app is NOT for diagnosis or treatment.")
                        DisclaimerItem(text: "Consult a healthcare provider for vitamin D testing, supplementation, and sun exposure guidance.")
                        DisclaimerItem(text: "Estimates are based on simplified scientific models with significant uncertainty.")
                    }
                }
                .softCard()
                .padding(.horizontal, 24)

                Text("By continuing, you acknowledge this disclaimer.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer(minLength: 40)
            }
        }
    }
}

struct ExplanationRow: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.sunOrange)
                .frame(width: 24)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.textPrimary)
                Text(text)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.textSecondary)
            }
        }
    }
}

struct DisclaimerItem: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.sunOrange)
            Text(text)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.textPrimary)
        }
    }
}

#Preview {
    DisclaimerView()
}
