import SwiftUI
import CoreData

struct DeckListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Deck.createdAt, ascending: false)],
        animation: .default
    )
    private var decks: FetchedResults<Deck>
    
    @State private var showingCreateDeck = false
    @State private var showingAPISettings = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(decks) { deck in
                    NavigationLink(destination: DeckDetailView(deck: deck)) {
                        DeckRowView(deck: deck)
                    }
                }
                .onDelete(perform: deleteDecks)
            }
            .navigationTitle("Decks")
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingAPISettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCreateDeck = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                #else
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        showingAPISettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreateDeck = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                #endif
            }
            .sheet(isPresented: $showingCreateDeck) {
                DeckCreationView()
            }
            .sheet(isPresented: $showingAPISettings) {
                APISettingsView()
            }
        }
    }
    
    private func deleteDecks(offsets: IndexSet) {
        withAnimation {
            offsets.map { decks[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                print("Error deleting decks: \(error)")
            }
        }
    }
}

struct DeckRowView: View {
    @ObservedObject var deck: Deck
    
    var body: some View {
        HStack(spacing: 16) {
            deckIconView
            deckContentView
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(backgroundView)
        .overlay(overlayBorder)
    }
    
    private var deckIconView: some View {
        ZStack {
            if let customIcon = deck.customIcon {
                // Display custom generated icon with safe aspect ratio handling
                Group {
                    if customIcon.size.width > 0 && customIcon.size.height > 0 {
                        Image(uiImage: customIcon)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                            .shadow(color: deck.deckColor.opacity(0.3), radius: 4, x: 0, y: 2)
                            .onAppear {
                                print("🎨 DeckListView: Showing custom icon for '\(deck.name)' - size: \(customIcon.size)")
                            }
                    } else {
                        // Fall back to SF Symbol if custom icon is invalid
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [deck.deckColor, deck.deckColor.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 60, height: 60)
                            .shadow(color: deck.deckColor.opacity(0.3), radius: 4, x: 0, y: 2)
                        
                        Image(systemName: deck.deckIcon)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text("Invalid")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .onAppear {
                                print("⚠️ DeckListView: Invalid custom icon for '\(deck.name)' - size: \(customIcon.size)")
                            }
                    }
                }
            } else {
                // Fall back to SF Symbol with gradient background
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [deck.deckColor, deck.deckColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .shadow(color: deck.deckColor.opacity(0.3), radius: 4, x: 0, y: 2)
                
                Image(systemName: deck.deckIcon)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .onAppear {
                        let hasData = deck.customIconData != nil
                        let dataSize = deck.customIconData?.count ?? 0
                        print("🔍 DeckListView: No custom icon for '\(deck.name)' - hasIconData: \(hasData), dataSize: \(dataSize)")
                    }
                    .onLongPressGesture {
                        print("🔄 Manual deck icon regeneration triggered for deck: \(deck.name)")
                        Task {
                            if let newIcon = await DeckIconGenerationService.shared.generateIconForDeck(name: deck.name, description: deck.deckDescription) {
                                deck.setCustomIcon(newIcon)
                            }
                        }
                    }
                    .onTapGesture(count: 2) {
                        print("🔍 Manual deck icon scan triggered")
                        // Could implement batch deck icon generation here if needed
                    }
            }
        }
    }
    
    private var deckContentView: some View {
        VStack(alignment: .leading, spacing: 6) {
            headerRow
            
            if let description = deck.deckDescription, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            statsRow
        }
    }
    
    private var headerRow: some View {
        HStack {
            Text(deck.name)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Spacer()
            
            if deck.dueCount > 0 {
                dueBadge
            }
        }
    }
    
    private var dueBadge: some View {
        Text("\(deck.dueCount)")
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                LinearGradient(
                    colors: [Color.red, Color.pink],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
            .shadow(color: Color.red.opacity(0.3), radius: 2, x: 0, y: 1)
    }
    
    private var statsRow: some View {
        HStack(spacing: 12) {
            cardCountView
            
            if deck.newCount > 0 {
                newCardsView
            }
            
            Spacer()
            
            if deck.totalCards > 0 {
                progressView
            }
        }
    }
    
    private var cardCountView: some View {
        HStack(spacing: 4) {
            Image(systemName: "rectangle.stack.fill")
                .font(.caption)
                .foregroundColor(deck.deckColor)
            Text("\(deck.totalCards)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(deck.deckColor)
        }
    }
    
    private var newCardsView: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.caption)
                .foregroundColor(.green)
            Text("\(deck.newCount) new")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.green)
        }
    }
    
    private var progressView: some View {
        let progress = deck.completionPercentage
        return VStack(alignment: .trailing, spacing: 2) {
            Text("\(Int(progress.isNaN ? 0 : progress * 100))%")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(deck.deckColor)
            
            ProgressView(value: progress.isNaN ? 0 : progress)
                .progressViewStyle(LinearProgressViewStyle(tint: deck.deckColor))
                .frame(width: 60)
        }
    }
    
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(
                LinearGradient(
                    colors: [
                        deck.deckColor.opacity(0.05),
                        deck.deckColor.opacity(0.02)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
    
    private var overlayBorder: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(deck.deckColor.opacity(0.2), lineWidth: 1)
    }
}

#Preview {
    DeckListView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}