import SwiftUI
import CoreData

struct CardSuggestionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    @StateObject private var backgroundImageService = BackgroundImageGenerationService.shared
    let deck: Deck
    
    @State private var dragOffset = CGSize.zero
    @State private var showingPreview = false
    @State private var showingCardCreation = false
    @State private var currentSuggestionCopy: Card?
    @State private var prefillText: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .font(.title2)
                            .foregroundColor(.orange)
                        
                        Text("Suggested Cards")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    let currentSuggestions = backgroundImageService.getSuggestions(for: deck)
                    if !currentSuggestions.isEmpty {
                        Text("\(currentSuggestions.count) suggestions available")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 16)
                
                // Main content area
                if let suggestion = backgroundImageService.getCurrentSuggestion(for: deck) {
                    suggestionCardView(suggestion)
                        .padding(.horizontal, 20)
                } else {
                    // Show empty state when no suggestions available
                    emptyStateView
                }
                
                Spacer()
                
                // Action buttons (only show when there are suggestions)
                if backgroundImageService.getCurrentSuggestion(for: deck) != nil {
                    actionButtonsView
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                }
                
                // Progress indicator (only show when there are suggestions)
                let currentSuggestions = backgroundImageService.getSuggestions(for: deck)
                if !currentSuggestions.isEmpty {
                    progressIndicatorView
                        .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .background(
                LinearGradient(
                    colors: [
                        deck.deckColor.opacity(0.06),
                        deck.deckColor.opacity(0.02),
                        Color(.systemBackground)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
            }
        }
        .sheet(isPresented: $showingPreview) {
            if let suggestion = currentSuggestionCopy {
                SuggestionPreviewView(
                    suggestion: suggestion,
                    deck: deck,
                    onCreateCard: { 
            // Store the suggestion text before dismissing the preview
                        prefillText = suggestion.front
                        showingPreview = false
                        // Add a small delay to ensure the first sheet is dismissed before showing the second
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            showingCardCreation = true
                        }
                    },
                    onDismiss: { showingPreview = false }
                )
            }
        }
.sheet(isPresented: $showingCardCreation) {
            CardCreationView(
                deck: deck,
                prefillFront: prefillText
            )
.onDisappear {
                // Move to next suggestion after card creation
                backgroundImageService.nextSuggestion(for: deck)
                // Clear the stored text
                prefillText = ""
                currentSuggestionCopy = nil
            }
        }
.onAppear {
            // Wake up the sweeper to ensure suggestions are maintained
            backgroundImageService.scanAndQueueMissingImages()
        }
    }
    
    @ViewBuilder
    private func suggestionCardView(_ suggestion: Card) -> some View {
        VStack(spacing: 20) {
            // Use unified StructuredCardView for consistent rendering (show back side)
            StructuredCardView(
                card: suggestion,
                side: .back,
                showFlipIcon: false
            )
            .frame(height: CardConstants.Dimensions.cardContentHeight)
            .offset(x: dragOffset.width)
            .rotationEffect(.degrees(Double(dragOffset.width / 20)))
            .overlay(
                // Add suggestion badge overlay
                VStack {
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "lightbulb.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                            
                            Text("Suggestion")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(.orange.opacity(0.1))
                                .overlay(
                                    Capsule()
                                        .stroke(.orange.opacity(0.3), lineWidth: 0.5)
                                )
                        )
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    
                    Spacer()
                },
                alignment: .topLeading
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                            if value.translation.width > 100 {
                                // Swipe right - add card
                                dragOffset = CGSize(width: 400, height: 0)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    addCurrentCard()
                                    resetCardPosition()
                                }
                            } else if value.translation.width < -100 {
                                // Swipe left - skip
                                dragOffset = CGSize(width: -400, height: 0)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    skipCurrentCard()
                                    resetCardPosition()
                                }
                            } else {
                                dragOffset = .zero
                            }
                        }
                    }
            )
            
            // Swipe indicators
            HStack {
                Label("Skip", systemImage: "xmark")
                    .font(.caption)
                    .foregroundColor(dragOffset.width < -50 ? .red : .secondary)
                
                Spacer()
                
                Label("Add", systemImage: "plus")
                    .font(.caption)
                    .foregroundColor(dragOffset.width > 50 ? .green : .secondary)
            }
            .padding(.horizontal, 40)
        }
    }
    
    @ViewBuilder
    private var loadingStateView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .controlSize(.large)
                .foregroundColor(.blue)
            
            Text("Finding More Cards...")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("AI is generating new card suggestions for you.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Return to Deck") {
                dismiss()
            }
            .font(.subheadline)
            .foregroundColor(.blue)
            .padding(.top, 20)
        }
        .padding(.top, 60)
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundColor(.blue)
            
            Text("No More Suggestions")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("New suggestions will automatically appear as you add more cards to your deck. The AI continuously learns from your progress!")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Return to Deck") {
                dismiss()
            }
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue)
            )
        }
        .padding(.top, 60)
    }
    
    @ViewBuilder
    private var actionButtonsView: some View {
        HStack {
            Spacer()
            
// Preview button (centered)
            Button("Preview") {
                currentSuggestionCopy = backgroundImageService.getCurrentSuggestion(for: deck)
                showingPreview = true
            }
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [deck.deckColor, deck.deckColor.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(color: deck.deckColor.opacity(0.3), radius: 4, x: 0, y: 2)
.disabled(backgroundImageService.getCurrentSuggestion(for: deck) == nil)
            
            Spacer()
        }
    }
    
@ViewBuilder
    private var progressIndicatorView: some View {
        let currentSuggestions = backgroundImageService.getSuggestions(for: deck)
        
        VStack(spacing: 12) {
            // Progress bar showing remaining suggestions
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Text("\(currentSuggestions.count) more suggestions")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
private func addCurrentCard() {
        guard let suggestion = backgroundImageService.getCurrentSuggestion(for: deck) else { return }
        
        // Create new card with complete suggestion data
        let newCard = Card(context: viewContext)
        newCard.id = UUID()
        newCard.front = suggestion.front
        
        // Set card type from suggestion
        newCard.cardType = suggestion.cardType
        
        // Use the structured content from suggestion
        newCard.jsonContent = suggestion.jsonContent
        newCard.back = "" // Clear legacy back field
        
        // Store image prompt if provided
        if let imagePrompt = suggestion.imagePrompt {
            newCard.imagePrompt = imagePrompt
        }
        
        newCard.createdAt = Date()
        newCard.easeFactor = 2.5
        newCard.interval = 0
        newCard.repetitions = 0
        newCard.reviewCount = 0
        newCard.setArchived(false, at: nil)
        
        // Card is complete since it has structured content
        
        newCard.deck = deck
        deck.addToCards(newCard)
        
        do {
            try viewContext.save()
            viewContext.refresh(deck, mergeChanges: true)
            
            // Play card added sound
            SoundService.shared.playCardAdded()
            
// Track this card as added to prevent it from appearing again
            backgroundImageService.trackAddedSuggestion(suggestion.front, type: suggestion.cardType.rawValue, for: deck)
            
            // Move to next suggestion
            backgroundImageService.nextSuggestion(for: deck)
        } catch {
            print("Error saving suggested card: \(error)")
        }
    }
    
private func skipCurrentCard() {
        backgroundImageService.nextSuggestion(for: deck)
    }
    
    private func resetCardPosition() {
        dragOffset = .zero
    }
}

struct SuggestionPreviewView: View {
    let suggestion: Card
    let deck: Deck
    let onCreateCard: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Card type
                HStack {
                    Text("\(suggestion.cardType.icon) \(suggestion.cardType.displayName)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                // Card preview using unified StructuredCardView
                VStack(spacing: 20) {
                    Text("Card Preview")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    StructuredCardView(
                        card: suggestion,
                        side: .back,
                        showFlipIcon: false
                    )
                    .frame(height: min(CardConstants.Dimensions.cardContentHeight, 300))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                
                // Context explanation
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.orange)
                        Text("Why this card?")
                            .font(.headline)
                    }
                    
                    Text("Suggested card for this deck")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Actions
                VStack(spacing: 12) {
                    Button("Create Card") {
                        onCreateCard()
                    }
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.green)
                    )
                    
                    Text("Opens the card creation view where you can generate and edit the back")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(20)
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        onDismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let deck = Deck(context: context)
    deck.name = "Italian"
    deck.id = UUID()
    
    return CardSuggestionView(deck: deck)
        .environment(\.managedObjectContext, context)
}