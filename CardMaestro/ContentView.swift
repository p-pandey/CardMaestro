//
//  ContentView.swift
//  CardMaestro
//
//  Created by Prashant Pandey on 8/9/25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        TabView {
            DeckListView()
                .tabItem {
                    Image(systemName: "rectangle.stack.fill")
                    Text("Decks")
                }
            
            AnalyticsView(viewContext: viewContext)
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Progress")
                }
        }
        .accentColor(.purple)
        .background(
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemGroupedBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
