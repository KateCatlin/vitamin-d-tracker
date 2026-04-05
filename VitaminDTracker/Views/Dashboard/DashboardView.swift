import SwiftUI

/// Main dashboard screen showing the user's estimated vitamin D level.
struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Main level card
                    VitaminDLevelCard(viewModel: viewModel)

                    // Baseline and supplement info
                    HStack(spacing: 12) {
                        InfoCard(
                            title: "Baseline",
                            value: viewModel.baselineLevelText,
                            icon: "chart.line.downtrend.xyaxis"
                        )
                        InfoCard(
                            title: "Supplement",
                            value: viewModel.supplementText,
                            icon: "pills.fill"
                        )
                    }
                    .padding(.horizontal, 20)

                    // Recent session card
                    RecentSessionCard(summary: viewModel.lastSessionSummary)
                        .padding(.horizontal, 20)

                    // Disclaimer banner
                    DisclaimerBanner()
                        .padding(.horizontal, 20)
                }
                .padding(.vertical, 16)
            }
            .background(Color.white)
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                viewModel.loadData()
                AnalyticsService.shared.log(.appOpen)
            }
            .refreshable {
                viewModel.loadData()
            }
        }
    }
}

// MARK: - Vitamin D Level Card

struct VitaminDLevelCard: View {
    @ObservedObject var viewModel: DashboardViewModel

    var body: some View {
        VStack(spacing: 16) {
            // Level label
            HStack {
                Text("Estimated Vitamin D")
                    .sectionHeading()
                Spacer()
                SourceBadge(
                    text: viewModel.sourceLabel,
                    color: viewModel.currentEstimate?.source == .labMeasurement
                        ? .healthGreen : .sunOrange
                )
            }

            // Big number
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(viewModel.estimatedLevelText)
                    .largeNumber()
                    .foregroundColor(viewModel.levelColor)
                Text(viewModel.estimatedLevelUnit)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.textSecondary)
            }

            // Interpretation
            Text(viewModel.levelInterpretation)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(viewModel.levelColor)

            // Confidence
            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                Text("Confidence: \(viewModel.confidenceLabel)")
                    .font(.system(size: 12, design: .rounded))
            }
            .foregroundColor(.textSecondary)
        }
        .softCard()
        .padding(.horizontal, 20)
    }
}

// MARK: - Info Card

struct InfoCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(.sunOrange)
                    .font(.system(size: 14))
                Text(title)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.textSecondary)
            }

            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .softCard()
    }
}

// MARK: - Recent Session Card

struct RecentSessionCard: View {
    let summary: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sun.max.fill")
                    .foregroundColor(.sunYellow)
                    .font(.system(size: 14))
                Text("Recent Sun Session")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.textSecondary)
            }

            Text(summary)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .softCard()
    }
}
