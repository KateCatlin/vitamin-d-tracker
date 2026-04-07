import SwiftUI
import VitaminDTrackerCore

// MARK: - Color Palette

/// Design system colors inspired by sunlight and sky.
/// Light, bright, optimistic palette with yellows and light blues.
extension Color {
    /// Primary golden/sunshine yellow.
    static let sunYellow = Color(red: 1.0, green: 0.82, blue: 0.28)
    /// Lighter sunshine accent.
    static let sunYellowLight = Color(red: 1.0, green: 0.93, blue: 0.65)
    /// Warm orange for emphasis.
    static let sunOrange = Color(red: 1.0, green: 0.65, blue: 0.25)
    /// Light sky blue.
    static let skyBlue = Color(red: 0.53, green: 0.81, blue: 0.98)
    /// Very light sky blue for backgrounds.
    static let skyBlueLight = Color(red: 0.88, green: 0.95, blue: 1.0)
    /// Soft green for "sufficient" ranges.
    static let healthGreen = Color(red: 0.45, green: 0.82, blue: 0.45)
    /// Soft red for warnings.
    static let warningRed = Color(red: 0.93, green: 0.35, blue: 0.35)
    /// Card background (very slight warm tint).
    static let cardBackground = Color(red: 1.0, green: 0.99, blue: 0.97)
    /// Subtle divider color.
    static let subtleDivider = Color(red: 0.92, green: 0.92, blue: 0.90)
    /// Text primary.
    static let textPrimary = Color(red: 0.15, green: 0.15, blue: 0.18)
    /// Text secondary.
    static let textSecondary = Color(red: 0.45, green: 0.45, blue: 0.50)
}

// MARK: - Card Style

/// A soft card view modifier.
struct SoftCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Color.cardBackground)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

extension View {
    func softCard() -> some View {
        modifier(SoftCardModifier())
    }
}

// MARK: - Typography

/// A friendly title style.
struct FriendlyTitleStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundColor(.textPrimary)
    }
}

/// A section heading style.
struct SectionHeadingStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundColor(.textPrimary)
    }
}

/// A body text style.
struct BodyTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 15, weight: .regular, design: .rounded))
            .foregroundColor(.textSecondary)
    }
}

/// Large number display style.
struct LargeNumberStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 48, weight: .bold, design: .rounded))
            .foregroundColor(.textPrimary)
    }
}

extension View {
    func friendlyTitle() -> some View { modifier(FriendlyTitleStyle()) }
    func sectionHeading() -> some View { modifier(SectionHeadingStyle()) }
    func bodyText() -> some View { modifier(BodyTextStyle()) }
    func largeNumber() -> some View { modifier(LargeNumberStyle()) }
}

// MARK: - Buttons

/// Primary action button style.
struct SunButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [Color.sunYellow, Color.sunOrange],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(14)
            .shadow(color: Color.sunOrange.opacity(0.3), radius: 6, x: 0, y: 3)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Secondary/outline button style.
struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundColor(.sunOrange)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.sunOrange, lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Status Badge

/// Shows the source/confidence of a value.
struct SourceBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .cornerRadius(6)
    }
}

// MARK: - Disclaimer Banner

struct DisclaimerBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.sunOrange)
                .font(.system(size: 14))
            Text("Estimates only — not medical advice")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.sunYellowLight.opacity(0.5))
        .cornerRadius(10)
    }
}

// MARK: - Fitzpatrick Skin Type Colors

extension FitzpatrickSkinType {
    /// UI color representing this skin type.
    var displayColor: Color {
        switch self {
        case .typeI:   return Color(red: 1.0, green: 0.90, blue: 0.82)
        case .typeII:  return Color(red: 0.96, green: 0.84, blue: 0.72)
        case .typeIII: return Color(red: 0.85, green: 0.72, blue: 0.58)
        case .typeIV:  return Color(red: 0.72, green: 0.58, blue: 0.44)
        case .typeV:   return Color(red: 0.55, green: 0.40, blue: 0.28)
        case .typeVI:  return Color(red: 0.38, green: 0.26, blue: 0.18)
        }
    }
}

// MARK: - Progress Ring

struct ProgressRing: View {
    let progress: Double // 0.0 to 1.0+
    let lineWidth: CGFloat
    let size: CGFloat

    var ringColor: Color {
        if progress >= 1.0 { return .warningRed }
        if progress >= 0.75 { return .sunOrange }
        return .sunYellow
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.subtleDivider, lineWidth: lineWidth)
                .frame(width: size, height: size)
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(ringColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)
        }
    }
}

#Preview("Design System") {
    ScrollView {
        VStack(spacing: 20) {
            Text("Friendly Title")
                .friendlyTitle()
            Text("Section Heading")
                .sectionHeading()
            Text("Body text style")
                .bodyText()
            SourceBadge(text: "Supplement", color: .blue)
            DisclaimerBanner()
            ProgressRing(progress: 0.65, lineWidth: 8, size: 80)
        }
        .padding()
    }
}
