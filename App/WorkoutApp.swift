import SwiftUI

@main
struct WorkoutApp: App {
    @StateObject private var store = WorkoutStore()
    @AppStorage("prefersBiometrics") private var prefersBiometrics = true

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(store.themeManager)
                .task {
                    await store.start()
                }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: WorkoutStore
    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        TabView {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("Home", systemImage: "bolt.heart")
            }

            NavigationStack {
                MetricsView()
            }
            .tabItem {
                Label("Metrics", systemImage: "chart.bar.xaxis")
            }

            NavigationStack {
                GymLocationsView()
            }
            .tabItem {
                Label("Gyms", systemImage: "mappin.and.ellipse")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .preferredColorScheme(theme.preferredColorScheme)
    }
}
