//
//  Puzzle_GardenApp.swift
//  Puzzle Garden
//
//  Created by Nathan Stickney on 6/12/26.
//

import SwiftUI

@main
struct Puzzle_GardenApp: App {
    private let playerData = PlayerData.shared
    private let storeManager = StoreManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView(playerData: playerData, storeManager: storeManager)
        }
    }
}
