import SwiftUI
import CoreData

struct CardCreationView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let deck: Deck
let prefillFront: String?
    let editingCard: Card? // Optional card for editing scenarios
    
    @State private var front = ""
    @State private var back = ""
    @State private var selectedCardType: CardType = .vocabulary
    @State private var currentImagePrompt: String?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingAPIKeyAlert = false
    @State private var showingAPISettings = false
    @State private var showingDuplicateAlert = false
    @State private var imageRemoved = false
    @State private var viewRefreshTrigger = UUID()
    @StateObject private var gptService = GPT5MiniService()
    
    private let originalFront: String
    
init(deck: Deck, prefillFront: String? = nil, editingCard: Card? = nil) {
        self.deck = deck
        self.prefillFront = prefillFront
        self.editingCard = editingCard
        self.originalFront = editingCard?.front ?? ""
        
        // Initialize state with existing card data if editing
        let frontValue = editingCard?.front ?? prefillFront ?? ""
        let backValue = editingCard?.jsonContent ?? ""
        
        self._front = State(initialValue: frontValue)
        self._back = State(initialValue: backValue)
        self._selectedCardType = State(initialValue: editingCard?.cardType ?? .vocabulary)
        self._currentImagePrompt = State(initialValue: editingCard?.imagePrompt)
        
        // Debug logging
        if let card = editingCard {
            print("🃏 CardCreationView: Editing card with front='\(card.front)' jsonContent='\(card.jsonContent ?? "nil")'")
            print("🃏 CardCreationView: Initialized front='\(frontValue)' back='\(backValue)'")
        } else if let prefill = prefillFront {
            print("🃏 CardCreationView: Prefilling with front='\(prefill)'")
        } else {
            print("🃏 CardCreationView: Creating new card")
        }
    }
    
    var isEditing: Bool {
        return editingCard != nil
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Card Front") {
                    VStack(alignment: .leading, spacing: 8) {
                        TextEditor(text: $front)
                            .frame(minHeight: 80)
                        
                        if gptService.hasValidKey {
                            Button(action: {
                                SoundService.shared.playButtonTap()
                                generateCardBack()
                            }) {
                                HStack(spacing: 8) {
                                    if gptService.isGenerating {
                                        ProgressView()
                                            .controlSize(.mini)
                                    } else {
                                        Image(systemName: "wand.and.stars")
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    Text(gptService.isGenerating ? "Generating..." : "Generate")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.blue, Color.blue.opacity(0.8)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                )
                                .shadow(color: Color.blue.opacity(0.3), radius: 2, x: 0, y: 1)
                            }
                            .disabled(front.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || gptService.isGenerating)
                        } else {
                            Button("Add OpenAI API Key to Generate") {
                                showingAPIKeyAlert = true
                            }
                            .font(.caption)
                            .foregroundColor(.orange)
                        }
                    }
                }
                
                Section("Card Type") {
                    ExpandableCardTypePicker(
                        selectedCardType: $selectedCardType,
                        onSelectionChanged: {
                            SoundService.shared.playButtonTap()
                        }
                    )
                }
                
                // Card Image Section (only for editing existing cards)
                if isEditing, let editingCard = editingCard, editingCard.hasCustomImage && !imageRemoved {
                    Section("Card Image") {
                        HStack {
                            if let customImage = editingCard.customImage {
                                Image(uiImage: customImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            
                            Spacer()
                            
                            Button(action: removeCardImage) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .id(viewRefreshTrigger) // Force view recreation when trigger changes
                }
                
                // Image Prompt Section
                Section("Image Prompt") {
                    VStack(alignment: .leading, spacing: 12) {
                        TextEditor(text: Binding(
                            get: { currentImagePrompt ?? "" },
                            set: { currentImagePrompt = $0.isEmpty ? nil : $0 }
                        ))
                        .frame(minHeight: 60)
                        
                        HStack {
                            Spacer()
                            
                            Button("Clear") {
                                currentImagePrompt = nil
                            }
                            .font(.caption)
                            .foregroundColor(.orange)
                        }
                        
                        Text("Describe the image you want for this card. Images are automatically generated with Apple Intelligence when needed.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Card Back") {
                    TextEditor(text: $back)
                        .frame(minHeight: 120)
                    
                    if let error = gptService.lastError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Card" : "New Card")
            .onAppear {
                print("🃏 CardCreationView: onAppear - isEditing: \(isEditing), front: '\(front)', back: '\(back)'")
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        SoundService.shared.playButtonTap()
                        saveCard()
                    }
                    .disabled(front.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                             back.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCard()
                    }
                    .disabled(front.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                             back.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                #endif
            }
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .alert("API Key Required", isPresented: $showingAPIKeyAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Settings") {
                showingAPISettings = true
            }
        } message: {
            Text("Add your OpenAI API key in Settings to use AI-generated card content.")
        }
        .sheet(isPresented: $showingAPISettings) {
            APISettingsView()
                .onDisappear {
                    // Refresh the Claude service key status when returning from settings
                    gptService.objectWillChange.send()
                }
        }
        .alert("Duplicate Card", isPresented: $showingDuplicateAlert) {
            Button("OK", role: .cancel) { }
            if isEditing {
                Button("Save Anyway") {
                    saveCardIgnoringDuplicate()
                }
            }
        } message: {
            Text("A card with this front text already exists in this deck. Please use different text for the front of the card.")
        }
    }
    
    private func removeCardImage() {
        guard let editingCard = editingCard else { return }
        
        // 1. Set local flag to immediately hide the UI
        imageRemoved = true
        
        // 2. Force the observed object to notify of changes
        editingCard.objectWillChange.send()
        
        // 3. Clear the custom image from the card
        editingCard.clearCustomImage()
        
        // 4. Save the change immediately
        do {
            try viewContext.save()
            
            // 5. Force refresh the entire managed object context
            viewContext.refreshAllObjects()
            
            // 6. Force refresh the specific card object
            viewContext.refresh(editingCard, mergeChanges: true)
            
            // 7. Trigger view recreation by changing the UUID
            viewRefreshTrigger = UUID()
            
            print("🗑️ Removed custom image from card: \(editingCard.front)")
        } catch {
            print("❌ Failed to save after removing card image: \(error)")
            alertMessage = "Failed to remove image: \(error.localizedDescription)"
            showingAlert = true
            
            // Reset the flag if save failed
            imageRemoved = false
        }
    }
    
    private func generateCardBack() {
        let frontText = front.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !frontText.isEmpty else { return }
        
        Task {
            do {
                let suggestion = try await gptService.generateCardBack(
                    front: frontText,
                    deckName: deck.name,
                    deckDescription: deck.deckDescription,
                    cardType: selectedCardType
                )
                
                await MainActor.run {
                    // The response should always be JSON now
                    back = suggestion.formattedBack
                    print("📄 Generated JSON content for \(selectedCardType.displayName) card")
                    
                    currentImagePrompt = suggestion.imagePrompt
                    if let imagePrompt = suggestion.imagePrompt {
                        print("💾 Stored image prompt for card: '\(imagePrompt)'")
                    }
                }
            } catch {
                await MainActor.run {
                    print("❌ Card generation failed: \(error.localizedDescription)")
                    // Silent failure - no alert shown to user
                }
            }
        }
    }
    
    private func saveCard() {
        let trimmedFront = front.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for duplicates with proper exclusion for editing
        if isEditing {
            // For editing, only check if front text has changed
            if trimmedFront.lowercased() != originalFront.lowercased() {
                if deck.hasDuplicateCard(front: trimmedFront, type: selectedCardType, excluding: editingCard) {
                    showingDuplicateAlert = true
                    return
                }
            }
        } else {
            // For creation, always check for duplicates
            if deck.hasDuplicateCard(front: trimmedFront, type: selectedCardType) {
                showingDuplicateAlert = true
                return
            }
        }
        
        saveCardIgnoringDuplicate()
    }
    
    private func saveCardIgnoringDuplicate() {
        if let editingCard = editingCard {
            // Update existing card
            editingCard.front = front.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedBack = back.trimmingCharacters(in: .whitespacesAndNewlines)
            editingCard.cardType = selectedCardType
            
            // All content is now JSON - store in jsonContent field
            if !trimmedBack.isEmpty {
                editingCard.jsonContent = trimmedBack
                editingCard.back = "" // Clear legacy back field
                print("💾 Stored JSON content in jsonContent field")
            }
            
            // Store the image prompt as metadata if we have one
            if let imagePrompt = currentImagePrompt {
                editingCard.imagePrompt = imagePrompt
            }
            
        } else {
            // Create new card
            let newCard = Card(context: viewContext)
            newCard.id = UUID()
            newCard.front = front.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedBack = back.trimmingCharacters(in: .whitespacesAndNewlines)
            newCard.createdAt = Date()
            newCard.easeFactor = 2.5
            newCard.interval = 0
            newCard.repetitions = 0
            newCard.reviewCount = 0
            newCard.setArchived(false, at: nil)
            
            // All content is now JSON - store in jsonContent field
            if !trimmedBack.isEmpty {
                newCard.jsonContent = trimmedBack
                newCard.back = "" // Keep back field empty for JSON cards
                print("💾 Stored JSON content in jsonContent field for new card")
            }
            
            
            // Set the card type
            newCard.cardType = selectedCardType
            
            // Store the image prompt as metadata
            newCard.imagePrompt = currentImagePrompt
            
            newCard.deck = deck
            deck.addToCards(newCard)
            
// Trigger sweeper to maintain suggestions after adding a new card
            DispatchQueue.main.async {
                BackgroundImageGenerationService.shared.scanAndQueueMissingImages()
            }
        }
        
        do {
            try viewContext.save()
            print("💾 Saved card '\(front)' to Core Data")
            
            // Force refresh of the deck's cards relationship
            viewContext.refresh(deck, mergeChanges: true)
            
            // Play card added sound
            SoundService.shared.playCardAdded()
            
            dismiss()
        } catch {
            alertMessage = "Failed to save card: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

struct CardTypeSelectionTile: View {
    let cardType: CardType
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: cardType.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : cardType.color)
                
                Text(cardType.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? cardType.color : Color(.secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(cardType.color.opacity(isSelected ? 0 : 0.3), lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CompactCardTypeButton: View {
    let cardType: CardType
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: cardType.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? .white : cardType.color)
                
                Text(cardType.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? cardType.color : Color(.secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(cardType.color.opacity(isSelected ? 0 : 0.4), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ExpandableCardTypePicker: View {
    @Binding var selectedCardType: CardType
    let onSelectionChanged: () -> Void
    @State private var isExpanded = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Selected card type display (collapsed state) - compact with just icon and name
            if !isExpanded {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: selectedCardType.icon)
                                .font(.title3)
                                .foregroundColor(selectedCardType.color)
                            
                            Text(selectedCardType.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.secondarySystemGroupedBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selectedCardType.color.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Expanded options - two per row
            if isExpanded {
                VStack(spacing: 12) {
                    // Collapse button
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isExpanded = false
                        }
                    }) {
                        HStack {
                            Text("Card Type")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.up")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.tertiarySystemGroupedBackground))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Grid of card types - two per row
                    let cardTypes = Array(CardType.allCases)
                    let rows = stride(from: 0, to: cardTypes.count, by: 2).map { i in
                        Array(cardTypes[i..<min(i + 2, cardTypes.count)])
                    }
                    
                    VStack(spacing: 8) {
                        ForEach(rows.indices, id: \.self) { rowIndex in
                            HStack(spacing: 8) {
                                ForEach(rows[rowIndex], id: \.self) { cardType in
                                    Button(action: {
                                        selectedCardType = cardType
                                        onSelectionChanged()
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            isExpanded = false
                                        }
                                    }) {
                                        VStack(spacing: 6) {
                                            Image(systemName: cardType.icon)
                                                .font(.title2)
                                                .foregroundColor(selectedCardType == cardType ? .white : cardType.color)
                                            
                                            Text(cardType.displayName)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .foregroundColor(selectedCardType == cardType ? .white : .primary)
                                            
                                            Text(cardType.description)
                                                .font(.caption2)
                                                .foregroundColor(selectedCardType == cardType ? .white.opacity(0.8) : .secondary)
                                                .multilineTextAlignment(.center)
                                                .lineLimit(2)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(selectedCardType == cardType ? cardType.color : Color(.secondarySystemGroupedBackground))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .stroke(cardType.color.opacity(selectedCardType == cardType ? 0 : 0.3), lineWidth: 1.5)
                                                )
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                
                                // Add spacer if odd number of items in last row
                                if rows[rowIndex].count == 1 {
                                    Spacer()
                                        .frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
    }
}

