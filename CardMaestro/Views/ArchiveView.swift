import SwiftUI
import CoreData

struct ArchiveView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    let deck: Deck
    
    var body: some View {
        NavigationView {
            List {
                ForEach(deck.archivedCards, id: \.objectID) { card in
                    ArchiveCardRowView(card: card)
                }
            }
            .navigationTitle("Archive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text("\(deck.archivedCards.count) cards")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct ArchiveCardRowView: View {
    let card: Card
    
    @Environment(\.managedObjectContext) private var viewContext
    @State private var dragOffset = CGSize.zero
    @State private var showToast = false
    @State private var toastMessage = ""
    
    var body: some View {
        ZStack {
            // Swipe action backgrounds
            HStack {
                // Right swipe action (Restore) - shown on left side
                if dragOffset.width > 0 {
                    Button(action: restoreCard) {
                        VStack {
                            Image(systemName: "arrow.uturn.left.circle.fill")
                                .font(.title2)
                            Text("Restore")
                                .font(.caption2)
                        }
                        .foregroundColor(.white)
                    }
                    .frame(width: min(dragOffset.width, 80))
                    .frame(maxHeight: .infinity)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                Spacer()
                
                // Left swipe action (Delete) - shown on right side
                if dragOffset.width < 0 {
                    Button(action: deleteCard) {
                        VStack {
                            Image(systemName: "trash.fill")
                                .font(.title2)
                            Text("Delete")
                                .font(.caption2)
                        }
                        .foregroundColor(.white)
                    }
                    .frame(width: min(-dragOffset.width, 80))
                    .frame(maxHeight: .infinity)
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            
            // Main card content
            HStack(spacing: 12) {
                // Card type icon with proper styling
                HStack(spacing: 8) {
                    Image(systemName: card.cardType.icon)
                        .font(.caption)
                        .foregroundColor(card.cardType.color)
                    
                    Text(card.cardType.displayName)
                        .font(.caption)
                        .foregroundColor(card.cardType.color)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(card.cardType.color.opacity(0.1))
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.front)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    if let archivedDate = card.archivedAt {
                        Text("Archived: \(formatDate(archivedDate))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Show custom image if available
                if let customImage = card.customImage {
                    Image(uiImage: customImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .liquidGlassSmallImage(cornerRadius: 6)
                }
            }
            .padding(.vertical, 4)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .offset(x: dragOffset.width)
        }
        .gesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    // Only register horizontal swipe if horizontal movement is significantly more than vertical
                    let horizontalMovement = abs(value.translation.width)
                    let verticalMovement = abs(value.translation.height)
                    
                    // Require horizontal movement to be at least 2x vertical movement to activate swipe
                    if horizontalMovement > verticalMovement * 2 && horizontalMovement > 30 {
                        dragOffset = value.translation
                    } else if horizontalMovement <= 30 {
                        // Reset offset for small movements to allow scrolling
                        dragOffset = .zero
                    }
                }
                .onEnded { value in
                    let horizontalMovement = abs(value.translation.width)
                    let verticalMovement = abs(value.translation.height)
                    
                    // Only trigger swipe action if it's a deliberate horizontal gesture
                    if horizontalMovement > verticalMovement * 2 {
                        if value.translation.width < -100 {
                            // Left swipe threshold reached - delete action (permanent deletion)
                            print("🗑️ Left swipe detected - permanently deleting card: '\(card.front)'")
                            deleteCard()
                        } else if value.translation.width > 100 {
                            // Right swipe threshold reached - restore action (add to deck)
                            print("📥 Right swipe detected - restoring card to deck: '\(card.front)'")
                            restoreCard()
                        } else {
                            // Reset position if threshold not met
                            withAnimation(.easeOut(duration: 0.3)) {
                                dragOffset = .zero
                            }
                        }
                    } else {
                        // Reset for non-horizontal gestures
                        withAnimation(.easeOut(duration: 0.3)) {
                            dragOffset = .zero
                        }
                    }
                }
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragOffset)
        .overlay(
            // Toast notification
            Group {
                if showToast {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text(toastMessage)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.red.opacity(0.9))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                            Spacer()
                        }
                        .padding(.bottom, 8)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showToast)
        )
    }
    
    private func deleteCard() {
        print("🗑️ Permanently deleting archived card: '\(card.front)'")
        SoundService.shared.playCardDeleted()
        viewContext.delete(card)
        try? viewContext.save()
    }
    
    private func restoreCard() {
        let deck = card.deck
        print("📥 Starting restore process for card: '\(card.front)' in deck: '\(deck.name)'")
        print("📊 Current deck has \(deck.activeCards.count) active cards")
        
        // Check if card already exists in active cards to prevent duplicates
        let existingCard = deck.activeCards.first { activeCard in
            activeCard.front.lowercased() == card.front.lowercased() && 
            activeCard.cardType.rawValue.lowercased() == card.cardType.rawValue.lowercased()
        }
        
        if existingCard != nil {
            print("⚠️ Duplicate found! Existing card: '\(existingCard!.front)' vs archived card: '\(card.front)'")
            // Show toast and delete the archived duplicate
            toastMessage = "Duplicate card deleted"
            withAnimation {
                showToast = true
            }
            
            // Auto-hide toast after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation {
                    showToast = false
                }
            }
            
            // Delete the archived duplicate
            SoundService.shared.playCardDeleted()
            viewContext.delete(card)
            try? viewContext.save()
            
            print("🗑️ Removed duplicate archived card: '\(card.front)'")
        } else {
            print("✅ No duplicate found, proceeding with restore")
            // No duplicate found, restore normally
            SoundService.shared.playButtonTap()
            card.setArchived(false, at: nil)
            try? viewContext.save()
            print("📥 Successfully restored card to deck: '\(card.front)'")
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct ArchiveCardPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    
    let card: Card
    @State private var showingFront = false
    @State private var flipDegrees = 180.0 // Start with back view
    
    var body: some View {
        NavigationView {
            VStack {
                Spacer()
                
                // Card display - starts with back view
                ZStack {
                    // Back of card (shown first)
                    StructuredCardView(
                        card: card,
                        side: .back,
                        showFlipIcon: false
                    )
                    .opacity(flipDegrees > 90 ? 1 : 0)
                    .rotation3DEffect(
                        .degrees(flipDegrees - 180),
                        axis: (x: 0, y: 1, z: 0)
                    )
                    
                    // Front of card
                    StructuredCardView(
                        card: card,
                        side: .front,
                        showFlipIcon: false
                    )
                    .opacity(flipDegrees > 90 ? 0 : 1)
                    .rotation3DEffect(
                        .degrees(flipDegrees),
                        axis: (x: 0, y: 1, z: 0)
                    )
                }
                .frame(minHeight: CardConstants.Dimensions.totalContainerHeight)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, CardConstants.Dimensions.horizontalPadding)
                .onTapGesture {
                    SoundService.shared.playCardFlip()
                    withAnimation(.easeInOut(duration: 0.6)) {
                        showingFront.toggle()
                    }
                }
                .onChange(of: showingFront) { _, newValue in
                    withAnimation(.easeInOut(duration: 0.6)) {
                        flipDegrees = newValue ? 0 : 180
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Archived Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let deck = Deck(context: context)
    deck.name = "Sample Deck"
    return ArchiveView(deck: deck)
        .environment(\.managedObjectContext, context)
}