import SwiftUI
import CoreData

struct CardEditView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var card: Card
    let deck: Deck
    
    @State private var front: String
    @State private var back: String
    @State private var imagePrompt: String
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingDuplicateAlert = false
    @State private var showingAPIKeyAlert = false
    @State private var showingAPISettings = false
    @State private var imageRemoved = false
    @State private var viewRefreshTrigger = UUID()
    @StateObject private var gptService = GPT5MiniService()
    
    private let originalFront: String
    
    init(card: Card, deck: Deck) {
        self.card = card
        self.deck = deck
        self.originalFront = card.front
        self._front = State(initialValue: card.front)
        self._back = State(initialValue: card.jsonContent ?? "")
        self._imagePrompt = State(initialValue: card.imagePrompt ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                cardFrontSection
                cardImageSection
                imagePromptSection
                cardBackSection
            }
            .navigationTitle("Edit Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
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
                    gptService.objectWillChange.send()
                }
        }
        .alert("Duplicate Card", isPresented: $showingDuplicateAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Save Anyway") {
                saveCardIgnoringDuplicate()
            }
        } message: {
            Text("A card with this front text already exists in this deck. Do you want to save it anyway?")
        }
    }
    
    private var cardFrontSection: some View {
        Section("Card Front") {
            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: $front)
                    .frame(minHeight: 80)
                
                generateButton
            }
        }
    }
    
    private var generateButton: some View {
        Group {
            if gptService.hasValidKey {
                Button(action: generateCardBack) {
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
                    .background(generateButtonBackground)
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
    
    private var generateButtonBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(
                LinearGradient(
                    colors: [Color.blue, Color.blue.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
    
    @ViewBuilder
    private var cardImageSection: some View {
        if card.hasCustomImage && !imageRemoved {
            Section("Card Image") {
                HStack {
                    if let customImage = card.customImage {
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
            .id(viewRefreshTrigger)
        }
    }
    
    private var imagePromptSection: some View {
        Section("Image Prompt") {
            VStack(alignment: .leading, spacing: 12) {
                TextEditor(text: $imagePrompt)
                    .frame(minHeight: 60)
                
                HStack {
                    Spacer()
                    
                    Button("Clear") {
                        imagePrompt = ""
                    }
                    .font(.caption)
                    .foregroundColor(.orange)
                }
                
                Text("Describe the image you want for this card. Images are automatically generated with Apple Intelligence when needed.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var cardBackSection: some View {
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
    
    private var toolbarContent: some ToolbarContent {
        Group {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
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
    
    // MARK: - Helper Methods
    
    private func removeCardImage() {
        // 1. Set local flag to immediately hide the UI
        imageRemoved = true
        
        // 2. Force the observed object to notify of changes
        card.objectWillChange.send()
        
        // 3. Clear the custom image from the card
        card.clearCustomImage()
        
        // 4. Save the change immediately
        do {
            try viewContext.save()
            
            // 5. Force refresh the entire managed object context
            viewContext.refreshAllObjects()
            
            // 6. Force refresh the specific card object
            viewContext.refresh(card, mergeChanges: true)
            
            // 7. Trigger view recreation by changing the UUID
            viewRefreshTrigger = UUID()
            
            print("🗑️ Removed custom image from card: \(card.front)")
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
                    deckDescription: deck.deckDescription
                )
                
                await MainActor.run {
                    back = suggestion.formattedBack
                    // Update image prompt if the AI generated one
                    if let newImagePrompt = suggestion.imagePrompt, !newImagePrompt.isEmpty {
                        imagePrompt = newImagePrompt
                        print("💾 Updated image prompt from AI: '\(newImagePrompt)'")
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
        
        // Only check for duplicates if the front text has changed
        if trimmedFront.lowercased() != originalFront.lowercased() {
            if deck.hasDuplicateCard(front: trimmedFront, type: card.cardType, excluding: card) {
                showingDuplicateAlert = true
                return
            }
        }
        
        saveCardIgnoringDuplicate()
    }
    
    private func saveCardIgnoringDuplicate() {
        card.front = front.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBack = back.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Store content in jsonContent field and clear legacy back field
        card.jsonContent = trimmedBack
        card.back = ""
        
        // Save the image prompt (empty string becomes nil)
        let trimmedImagePrompt = imagePrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        card.imagePrompt = trimmedImagePrompt.isEmpty ? nil : trimmedImagePrompt
        
        
        do {
            try viewContext.save()
            // Force refresh of the deck to update UI
            viewContext.refresh(deck, mergeChanges: true)
            dismiss()
        } catch {
            alertMessage = "Failed to save card: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let deck = Deck(context: context)
    deck.name = "Sample Deck"
    deck.createdAt = Date()
    deck.id = UUID()
    
    let card = Card(context: context)
    card.id = UUID()
    card.front = "Sample Front"
    card.jsonContent = "{\"meaning\": \"Sample meaning\", \"detail\": \"Sample detail\"}"
    card.cardType = .vocabulary
    card.createdAt = Date()
    card.easeFactor = 2.5
    card.deck = deck
    
    return CardEditView(card: card, deck: deck)
        .environment(\.managedObjectContext, context)
}