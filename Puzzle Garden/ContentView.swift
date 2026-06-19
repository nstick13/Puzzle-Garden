import SwiftUI

struct ContentView: View {
    var playerData: PlayerData
    var storeManager: StoreManager

    var body: some View {
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
        }
        .tint(Color(red: 0.25, green: 0.50, blue: 0.28))
    }
}

#Preview {
    ContentView(playerData: PlayerData.shared, storeManager: StoreManager.shared)
}
