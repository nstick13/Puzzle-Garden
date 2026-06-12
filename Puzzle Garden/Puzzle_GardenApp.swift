//
//  Puzzle_GardenApp.swift
//  Puzzle Garden
//
//  Created by Nathan Stickney on 6/12/26.
//

import SwiftUI
import CoreData

@main
struct Puzzle_GardenApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
