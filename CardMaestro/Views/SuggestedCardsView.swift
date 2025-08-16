import SwiftUI
import CoreData

struct SuggestedCardsView: View {
    let deck: Deck
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var backgroundService = BackgroundImageGenerationService.shared
    
    @State private var currentCardIndex = 0
    @State private var dragOffset = CGSize.zero
    @State private var showingCardEdit = false
    @State private var cardToEdit: Card?
    
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
                        // Progress indicator
                        HStack {
                            ForEach(0..<suggestedCards.count, id: \.self) { index in
                                Circle()
                                    .fill(index == currentCardIndex ? .blue : .gray.opacity(0.3))
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .padding(.top)
                        
                        Spacer()
                        
                        // Card with swipe gestures
                        StructuredCardView(
                            card: card,
                            side: .back,
                            showFlipIcon: false
                        )
                        .frame(height: CardConstants.Dimensions.cardContentHeight)
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
                            cardToEdit = card
                            showingCardEdit = true
                        }
                        
                        Spacer()
                        
                        // Action hints
                        HStack(spacing: 40) {
                            VStack(spacing: 8) {
                                Image(systemName: "archivebox")
                                    .font(.title2)
                                    .foregroundColor(.orange)
                                Text("Archive")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                Text("Swipe left")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .opacity(dragOffset.width < -50 ? 1.0 : 0.6)
                            
                            VStack(spacing: 8) {
                                Image(systemName: "plus.circle")
                                    .font(.title2)
                                    .foregroundColor(.green)
                                Text("Add to Deck")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                Text("Swipe right")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .opacity(dragOffset.width > 50 ? 1.0 : 0.6)
                        }
                        .padding(.bottom, 40)
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
        .sheet(item: $cardToEdit) { card in
            CardEditView(card: card, deck: deck)
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
        } else {
            // All cards processed
            currentCardIndex = 0
            dragOffset = .zero
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