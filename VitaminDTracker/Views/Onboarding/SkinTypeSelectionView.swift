import SwiftUI
import VitaminDTrackerCore

/// Fitzpatrick skin type selection step in onboarding.
struct SkinTypeSelectionView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("Your Skin Type")
                .friendlyTitle()
                .padding(.top, 24)

            Text("Your skin type affects how quickly you produce\nvitamin D from sunlight and your sunburn risk.")
                .bodyText()
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(FitzpatrickSkinType.allCases, id: \.rawValue) { skinType in
                        SkinTypeRow(
                            skinType: skinType,
                            isSelected: viewModel.selectedSkinType == skinType
                        )
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.selectedSkinType = skinType
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }
}

struct SkinTypeRow: View {
    let skinType: FitzpatrickSkinType
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Color indicator circle
            Circle()
                .fill(skinTypeColor)
                .frame(width: 32, height: 32)
                .overlay(
                    Circle()
                        .stroke(Color.subtleDivider, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(skinType.displayName)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.textPrimary)
                Text(skinType.sunResponse)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.sunOrange)
                    .font(.system(size: 20))
            }
        }
        .padding(12)
        .background(isSelected ? Color.sunYellowLight.opacity(0.4) : Color.cardBackground)
        .cornerRadius(12)
    }

    private var skinTypeColor: Color {
        skinType.displayColor
    }
}

#Preview {
    SkinTypeSelectionView(viewModel: OnboardingViewModel())
}
