import SwiftUI

struct ContentView: View {
    var playerData: PlayerData
    var storeManager: StoreManager

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showLaunch = true

    var body: some View {
        ZStack {
            TabView {
                HomeView(playerData: playerData, storeManager: storeManager)
                    .tabItem {
                        Label("Home", systemImage: "leaf.fill")
                    }

                GardenView(playerData: playerData)
                    .tabItem {
                        Label("Garden", systemImage: "tree.fill")
                    }

                StatsView(playerData: playerData)
                    .tabItem {
                        Label("Stats", systemImage: "chart.bar.fill")
                    }

                NavigationStack {
                    SettingsView()
                }
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
            }
            .tint(Color(red: 0.25, green: 0.50, blue: 0.28))

            if showLaunch {
                LaunchScreenView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeOut(duration: 0.4)) {
                    showLaunch = false
                }
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { !hasSeenOnboarding },
            set: { _ in }
        )) {
            OnboardingView {
                hasSeenOnboarding = true
            }
        }
    }
}

#Preview {
    ContentView(playerData: PlayerData.shared, storeManager: StoreManager.shared)
}
