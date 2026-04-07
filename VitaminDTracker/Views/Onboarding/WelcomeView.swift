import SwiftUI

/// Welcome screen shown at the start of onboarding.
struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Sun icon
            Image(systemName: "sun.max.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.sunYellow, .sunOrange],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .sunYellow.opacity(0.3), radius: 20, x: 0, y: 5)

            Text("Vitamin D Tracker")
                .friendlyTitle()

            Text("Estimate your vitamin D level using\nsun exposure, supplements, and lab results.")
                .bodyText()
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                FeatureRow(icon: "location.fill", text: "Set your home city for UV estimates")
                FeatureRow(icon: "cross.case.fill", text: "Enter lab results when available")
                FeatureRow(icon: "pills.fill", text: "Track your daily supplements")
                FeatureRow(icon: "sun.max.fill", text: "Log sun exposure sessions")
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.sunOrange)
                .frame(width: 24)
            Text(text)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundColor(.textPrimary)
            Spacer()
        }
    }
}

#Preview {
    WelcomeView()
}
