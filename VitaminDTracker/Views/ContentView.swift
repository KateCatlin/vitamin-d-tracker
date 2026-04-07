import SwiftUI

/// Root content view that decides between onboarding and the main app.
struct ContentView: View {
    @State private var hasCompletedOnboarding = PersistenceManager.shared.userProfile.hasCompletedOnboarding

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingContainerView {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        hasCompletedOnboarding = true
                    }
                }
            }
        }
    }
}

/// Main tab-based navigation after onboarding.
struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "sun.max.fill")
                }

            SunSessionView()
                .tabItem {
                    Label("Sun Session", systemImage: "sunrise.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(.sunOrange)
    }
}

#Preview {
    ContentView()
}
