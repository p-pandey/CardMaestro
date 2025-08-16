//
//  CardMaestroApp.swift
//  CardMaestro
//
//  Created by Prashant Pandey on 8/9/25.
//

import SwiftUI
import CoreData

@main
struct CardMaestroApp: App {
    let persistenceController = PersistenceController.shared
    @State private var showSplash = true
    
    init() {
        // Initialize the singleton sweeper when the app starts
        _ = BackgroundImageGenerationService.shared
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if showSplash {
                    SplashView()
                        .transition(.opacity)
                } else {
                    ContentView()
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                        .transition(.opacity)
                }
            }
            .onAppear {
                // Hide splash screen after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation(.easeInOut(duration: 0.8)) {
                        showSplash = false
                    }
                }
            }
        }
    }
}
