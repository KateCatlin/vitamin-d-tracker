import SwiftUI
import VitaminDTrackerCore

/// Sun exposure tracking session view.
struct SunSessionView: View {
    @StateObject private var viewModel = SunSessionViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if viewModel.isSessionActive {
                        ActiveSessionContent(viewModel: viewModel)
                    } else if let session = viewModel.currentSession, session.isCompleted {
                        SessionCompleteContent(viewModel: viewModel)
                    } else {
                        StartSessionContent(viewModel: viewModel)
                    }
                }
                .padding(.vertical, 16)
            }
            .background(Color.white)
            .navigationTitle("Sun Session")
            .navigationBarTitleDisplayMode(.large)
            .alert("☀️ Sun Exposure Warning", isPresented: $viewModel.showOverexposureAlert) {
                Button("Stop Session") {
                    viewModel.stopSession()
                }
                Button("Continue", role: .cancel) { }
            } message: {
                Text("You've reached the recommended maximum sun exposure time. Consider stopping to protect your skin.")
            }
        }
    }
}

// MARK: - Start Session Content

struct StartSessionContent: View {
    @ObservedObject var viewModel: SunSessionViewModel

    var body: some View {
        VStack(spacing: 24) {
            // Sun illustration
            Image(systemName: "sun.max.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.sunYellow, .sunOrange],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(.top, 20)

            Text("Start a Sun Session")
                .friendlyTitle()

            Text("Track your outdoor sun exposure\nto estimate vitamin D production.")
                .bodyText()
                .multilineTextAlignment(.center)

            // Parameters
            VStack(spacing: 16) {
                // Skin exposure
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Skin Exposure")
                            .sectionHeading()
                        Spacer()
                        Text(viewModel.skinExposureLabel)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.textSecondary)
                    }
                    Slider(value: $viewModel.skinExposureFraction, in: 0.05...1.0, step: 0.05)
                        .tint(.sunOrange)
                    Text("\(Int(viewModel.skinExposureFraction * 100))% of body surface")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.textSecondary)
                }

                Divider()

                // Cloud cover
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Cloud Cover")
                            .sectionHeading()
                        Spacer()
                        Text(viewModel.cloudCoverLabel)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.textSecondary)
                    }
                    Slider(value: $viewModel.cloudCoverFraction, in: 0.0...1.0, step: 0.1)
                        .tint(.skyBlue)
                    Text("\(Int(viewModel.cloudCoverFraction * 100))% cloud cover")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.textSecondary)
                }

                // Skin type info
                if let skinType = viewModel.userSkinType {
                    Divider()
                    HStack {
                        Text("Skin Type")
                            .sectionHeading()
                        Spacer()
                        Text(skinType.displayName)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.textSecondary)
                    }
                }
            }
            .softCard()
            .padding(.horizontal, 20)

            // Start button
            Button("Start Session") {
                viewModel.startSession()
            }
            .buttonStyle(SunButtonStyle())

            Spacer(minLength: 20)
        }
    }
}

// MARK: - Active Session Content

struct ActiveSessionContent: View {
    @ObservedObject var viewModel: SunSessionViewModel

    var body: some View {
        VStack(spacing: 24) {
            // Timer
            ZStack {
                ProgressRing(
                    progress: viewModel.exposurePercentage,
                    lineWidth: 12,
                    size: 180
                )

                VStack(spacing: 4) {
                    Text(viewModel.elapsedTimeFormatted)
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundColor(.textPrimary)
                    Text("elapsed")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.textSecondary)
                }
            }
            .padding(.top, 20)

            // Vitamin D gain
            VStack(spacing: 4) {
                Text(viewModel.gainFormatted)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.healthGreen)
                Text("Estimated Vitamin D Gain")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.textSecondary)
            }

            // Session info cards
            HStack(spacing: 12) {
                SessionInfoPill(
                    title: "UV Index",
                    value: String(format: "%.1f", viewModel.estimatedUVIndex),
                    color: viewModel.uvRiskLevel.shouldWarn ? .warningRed : .sunOrange
                )
                SessionInfoPill(
                    title: "UV Risk",
                    value: viewModel.uvRiskLevel.rawValue,
                    color: viewModel.uvRiskLevel.shouldWarn ? .warningRed : .healthGreen
                )
                SessionInfoPill(
                    title: "Safe Time",
                    value: viewModel.maxSafeTimeFormatted,
                    color: .skyBlue
                )
            }
            .padding(.horizontal, 20)

            // Overexposure warning
            if viewModel.isOverexposed {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.warningRed)
                    Text("Recommended exposure time exceeded!")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.warningRed)
                }
                .padding(12)
                .background(Color.warningRed.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal, 20)
            }

            // Adjustable parameters during session
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Skin Exposure: \(Int(viewModel.skinExposureFraction * 100))%")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.textSecondary)
                    Slider(value: $viewModel.skinExposureFraction, in: 0.05...1.0, step: 0.05)
                        .tint(.sunOrange)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Cloud Cover: \(Int(viewModel.cloudCoverFraction * 100))%")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.textSecondary)
                    Slider(value: $viewModel.cloudCoverFraction, in: 0.0...1.0, step: 0.1)
                        .tint(.skyBlue)
                }
            }
            .softCard()
            .padding(.horizontal, 20)

            // Stop button
            Button("Stop Session") {
                viewModel.stopSession()
            }
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 14)
            .background(Color.warningRed)
            .cornerRadius(14)

            Spacer(minLength: 20)
        }
    }
}

// MARK: - Session Complete Content

struct SessionCompleteContent: View {
    @ObservedObject var viewModel: SunSessionViewModel

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.healthGreen)
                .padding(.top, 20)

            Text("Session Complete!")
                .friendlyTitle()

            if let session = viewModel.currentSession {
                VStack(spacing: 16) {
                    SessionResultRow(label: "Duration", value: "\(Int(session.durationMinutes)) minutes")
                    SessionResultRow(
                        label: "Vitamin D Gained",
                        value: String(format: "+%.2f ng/mL", session.estimatedVitaminDGain)
                    )
                    SessionResultRow(
                        label: "UV Index",
                        value: String(format: "%.1f", session.estimatedUVIndex)
                    )
                    SessionResultRow(
                        label: "Skin Exposed",
                        value: "\(Int(session.skinExposureFraction * 100))%"
                    )
                }
                .softCard()
                .padding(.horizontal, 20)
            }

            Button("New Session") {
                viewModel.currentSession = nil
                viewModel.isSessionActive = false
                viewModel.elapsedSeconds = 0
                viewModel.estimatedGain = 0
            }
            .buttonStyle(SunButtonStyle())

            Spacer(minLength: 20)
        }
    }
}

// MARK: - Helper Views

struct SessionInfoPill: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.cardBackground)
        .cornerRadius(10)
    }
}

struct SessionResultRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.textPrimary)
        }
    }
}

#Preview {
    SunSessionView()
}
