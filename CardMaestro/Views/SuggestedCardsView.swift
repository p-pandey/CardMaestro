import SwiftUI
import CoreData

struct SuggestedCardsView: View {
    let deck: Deck
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var backgroundService = BackgroundImageGenerationService.shared
    
    @State private var currentCardIndex = 0
    @State private var dragOffset = CGSize.zero
    @State private var flippedCards: Set<UUID> = []
    
    // Get suggested cards for this deck
    private var suggestedCards: [Card] {
        backgroundService.getSuggestions(for: deck)
    }
    
    private var currentCard: Card? {
        guard currentCardIndex < suggestedCards.count else { return nil }
        return suggestedCards[currentCardIndex]
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if let card = currentCard {
                    VStack(spacing: 20) {
                        
                        Spacer()
                        
                        // Card with swipe gestures and background actions
                        ZStack {
                            // Swipe action backgrounds
                            swipeActionBackgrounds
                            
                            // Main card
                            StructuredCardView(
                                card: card,
                                side: flippedCards.contains(card.id) ? .front : .back,
                                showFlipIcon: false
                            )
                            .frame(
                                width: UIScreen.main.bounds.width - (CardConstants.Dimensions.horizontalPadding * 2),
                                height: CardConstants.Dimensions.cardContentHeight
                            )
                            .offset(x: dragOffset.width)
                            .rotationEffect(.degrees(dragOffset.width / 10))
                            .scaleEffect(1.0 - abs(dragOffset.width) / 1000)
                            .opacity(1.0 - abs(dragOffset.width) / 500.0)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        dragOffset = value.translation
                                    }
                                    .onEnded { value in
                                        handleSwipeEnd(translation: value.translation)
                                    }
                            )
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.6)) {
                                    if flippedCards.contains(card.id) {
                                        flippedCards.remove(card.id)
                                    } else {
                                        flippedCards.insert(card.id)
                                    }
                                }
                            }
                        }
                        
                        // Discrete curved arrows for swipe indication
                        swipeIndicatorArrows
                        
                        Spacer()
                    }
                } else {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text("All suggestions reviewed!")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Great work reviewing all the suggested cards for this deck.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Back to Deck") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top)
                    }
                }
            }
            .navigationTitle("Card Suggestions")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !suggestedCards.isEmpty {
                        Text("\(currentCardIndex + 1) of \(suggestedCards.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .onAppear {
            // Block new suggestions while user is in this view
            backgroundService.isUserReviewingSuggestions = true
        }
        .onDisappear {
            // Re-enable suggestions when leaving
            backgroundService.isUserReviewingSuggestions = false
        }
    }
    
    private func handleSwipeEnd(translation: CGSize) {
        let threshold: CGFloat = 100
        
        if translation.width < -threshold {
            // Swipe left - Archive
            archiveCurrentCard()
        } else if translation.width > threshold {
            // Swipe right - Add to deck
            addCurrentCardToDeck()
        } else {
            // Return to center
            withAnimation(.spring()) {
                dragOffset = .zero
            }
        }
    }
    
    private func archiveCurrentCard() {
        guard let card = currentCard else { return }
        
        withAnimation(.easeOut(duration: 0.3)) {
            dragOffset = CGSize(width: -1000, height: 0)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Check if card already exists in deck to prevent duplicates
            let existingCard = (deck.activeCards + deck.archivedCards).first { existingCard in
                existingCard.front.lowercased() == card.front.lowercased() && 
                existingCard.cardType.rawValue.lowercased() == card.cardType.rawValue.lowercased()
            }
            
            if existingCard != nil {
                print("⚠️ Card already exists in deck, skipping archive: '\(card.front)'")
                // Still remove the suggestion and track it
            } else {
                // Create a new archived card in the deck from the suggestion
                let archivedCard = Card(context: viewContext)
                archivedCard.id = UUID()
                archivedCard.front = card.front
                archivedCard.jsonContent = card.jsonContent
                archivedCard.back = "" // Clear legacy back field
                archivedCard.cardType = card.cardType
                archivedCard.imagePrompt = card.imagePrompt
                archivedCard.customImageData = card.customImageData
                archivedCard.createdAt = Date()
                archivedCard.easeFactor = 2.5
                archivedCard.interval = 0
                archivedCard.repetitions = 0
                archivedCard.reviewCount = 0
                archivedCard.setArchived(true, at: Date()) // Archive the card
                archivedCard.deck = deck
                print("✅ Archived card: '\(card.front)'")
            }
            
            // Track this as deleted to prevent re-suggestion
            backgroundService.trackAddedSuggestion(card.front, type: card.cardType.rawValue, for: deck)
            
            // Find and delete the corresponding suggestion Card
            if let suggestionCard = deck.visibleSuggestions.first(where: { $0.front == card.front && $0.cardType.rawValue == card.cardType.rawValue }) {
                viewContext.delete(suggestionCard)
            }
            
            try? viewContext.save()
            
            // Move to next card or reset
            moveToNextCard()
        }
    }
    
    private func addCurrentCardToDeck() {
        guard let card = currentCard else { return }
        
        withAnimation(.easeOut(duration: 0.3)) {
            dragOffset = CGSize(width: 1000, height: 0)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Check if card already exists in deck to prevent duplicates
            let existingCard = (deck.activeCards + deck.archivedCards).first { existingCard in
                existingCard.front.lowercased() == card.front.lowercased() && 
                existingCard.cardType.rawValue.lowercased() == card.cardType.rawValue.lowercased()
            }
            
            if existingCard != nil {
                print("⚠️ Card already exists in deck, skipping: '\(card.front)'")
                // Still remove the suggestion and track it
            } else {
                // Create a new card in the deck from the suggestion
                let newCard = Card(context: viewContext)
                newCard.id = UUID()
                newCard.front = card.front
                newCard.jsonContent = card.jsonContent
                newCard.back = "" // Clear legacy back field
                newCard.cardType = card.cardType
                newCard.imagePrompt = card.imagePrompt
                newCard.customImageData = card.customImageData
                newCard.createdAt = Date()
                newCard.easeFactor = 2.5
                newCard.interval = 0
                newCard.repetitions = 0
                newCard.reviewCount = 0
                newCard.setArchived(false, at: nil)
                newCard.deck = deck
                print("✅ Added card to deck: '\(card.front)'")
            }
            
            // Track this as added to prevent re-suggestion
            backgroundService.trackAddedSuggestion(card.front, type: card.cardType.rawValue, for: deck)
            
            // Find and delete the corresponding suggestion Card
            if let suggestionCard = deck.visibleSuggestions.first(where: { $0.front == card.front && $0.cardType.rawValue == card.cardType.rawValue }) {
                viewContext.delete(suggestionCard)
            }
            
            try? viewContext.save()
            
            // Move to next card or reset
            moveToNextCard()
        }
    }
    
    private func moveToNextCard() {
        if currentCardIndex < suggestedCards.count - 1 {
            currentCardIndex += 1
            dragOffset = .zero
            // Reset flip state for new card
            if let nextCard = currentCard {
                flippedCards.remove(nextCard.id)
            }
        } else {
            // All cards processed
            currentCardIndex = 0
            dragOffset = .zero
            flippedCards.removeAll()
        }
    }
    
    // MARK: - Swipe Visual Feedback
    
    private var swipeActionBackgrounds: some View {
        HStack {
            // Left side - Play action icon (shown during right swipe)
            VStack {
                if dragOffset.width > 10 {
                    Image(systemName: "play")
                        .font(.system(size: 50))
                        .foregroundColor(.primary)
                        .opacity(min(Double(dragOffset.width) / 50.0, 0.8))
                        .scaleEffect(min(Double(dragOffset.width) / 80.0, 1.1))
                        .animation(.easeOut(duration: 0.2), value: dragOffset.width)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Spacer()
            
            // Right side - Archive action icon (shown during left swipe)
            VStack {
                if dragOffset.width < -10 {
                    Image(systemName: "archivebox")
                        .font(.system(size: 50))
                        .foregroundColor(.primary)
                        .opacity(min(Double(abs(dragOffset.width)) / 50.0, 0.8))
                        .scaleEffect(min(Double(abs(dragOffset.width)) / 80.0, 1.1))
                        .animation(.easeOut(duration: 0.2), value: dragOffset.width)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(
            width: UIScreen.main.bounds.width - (CardConstants.Dimensions.horizontalPadding * 2),
            height: CardConstants.Dimensions.cardContentHeight
        )
    }
    
    private var swipeIndicatorArrows: some View {
        HStack(spacing: 60) {
            // Left curved arrow for archive
            Image(systemName: "arrow.turn.up.left")
                .font(.title3)
                .foregroundColor(arrowColor)
                .scaleEffect(dragOffset.width < -10 ? 1.2 : 1.0)
                .animation(.easeOut(duration: 0.2), value: dragOffset.width)
            
            Spacer()
            
            // Right curved arrow for add to deck
            Image(systemName: "arrow.turn.up.right")
                .font(.title3)
                .foregroundColor(arrowColor)
                .scaleEffect(dragOffset.width > 10 ? 1.2 : 1.0)
                .animation(.easeOut(duration: 0.2), value: dragOffset.width)
        }
        .padding(.horizontal, 40)
        .opacity(abs(dragOffset.width) < 5 ? 0.8 : 0.4) // Fade when actively swiping
        .animation(.easeOut(duration: 0.2), value: dragOffset.width)
    }
    
    @Environment(\.colorScheme) var colorScheme
    
    private var arrowColor: Color {
        switch colorScheme {
        case .dark:
            return Color.gray.opacity(0.7) // Lighter grey for dark mode
        case .light:
            return Color.gray.opacity(0.5) // Darker grey for light mode
        @unknown default:
            return Color.gray.opacity(0.6)
        }
    }
    
}

struct SuggestedCardsView_Previews: PreviewProvider {
    static var previews: some View {
        SuggestedCardsView(deck: makeDeck())
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
    
    static func makeDeck() -> Deck {
        let context = PersistenceController.preview.container.viewContext
        let deck = Deck(context: context)
        deck.name = "Sample Deck"
        return deck
    }
}