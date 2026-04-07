import SwiftUI

/// Root content view that decides between onboarding and the main app.
struct ContentView: View {
    // We snapshot this once at init because `PersistenceManager` isn't
    // observable. The Settings "Delete All Data" flow tells us to
    // re-read it via `.userDataDidReset`.
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
        .onReceive(
            NotificationCenter.default.publisher(for: .userDataDidReset)
        ) { _ in
            // resetAll() already wiped the profile; just re-read so the
            // UI flips back to onboarding. Animate so it doesn't pop.
            withAnimation(.easeInOut(duration: 0.5)) {
                hasCompletedOnboarding =
                    PersistenceManager.shared.userProfile.hasCompletedOnboarding
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
