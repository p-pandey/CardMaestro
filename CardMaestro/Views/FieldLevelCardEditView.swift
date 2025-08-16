import SwiftUI
import CoreData

/// Centralized field-level card editor that parses JSON content and generates UI for editing individual fields
struct FieldLevelCardEditView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var card: Card
    let deck: Deck
    
    @State private var front: String
    @State private var imagePrompt: String
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingDuplicateAlert = false
    @State private var showingAPIKeyAlert = false
    @State private var showingAPISettings = false
    @State private var imageRemoved = false
    @State private var viewRefreshTrigger = UUID()
    @StateObject private var gptService = GPT5MiniService()
    
    // Field-specific state for vocabulary cards
    @State private var vocabularyMeaning: String = ""
    @State private var vocabularyDetail: String = ""
    
    // Field-specific state for conjugation cards
    @State private var conjugationMeaning: String = ""
    @State private var conjugationRows: [[String]] = []
    
    // Field-specific state for fact cards
    @State private var factAnswer: String = ""
    @State private var factDetail: String = ""
    
    private let originalFront: String
    private let originalImagePrompt: String
    
    init(card: Card, deck: Deck) {
        self.card = card
        self.deck = deck
        self.originalFront = card.front
        self.originalImagePrompt = card.imagePrompt ?? ""
        self._front = State(initialValue: card.front)
        self._imagePrompt = State(initialValue: card.imagePrompt ?? "")
        
        // Initialize field-specific states based on card type and content
        if let content = card.structuredContent {
            switch content {
            case let vocabContent as VocabularyContent:
                self._vocabularyMeaning = State(initialValue: vocabContent.meaning)
                self._vocabularyDetail = State(initialValue: vocabContent.detail ?? "")
            case let conjugContent as ConjugationContent:
                self._conjugationMeaning = State(initialValue: conjugContent.meaning)
                self._conjugationRows = State(initialValue: conjugContent.conjugations)
            case let factContent as FactContent:
                self._factAnswer = State(initialValue: factContent.answer)
                self._factDetail = State(initialValue: factContent.detail ?? "")
            default:
                break
            }
        } else {
            // Initialize with default empty content
            switch card.cardType {
            case .vocabulary:
                self._vocabularyMeaning = State(initialValue: "")
                self._vocabularyDetail = State(initialValue: "")
            case .conjugation:
                self._conjugationMeaning = State(initialValue: "")
                self._conjugationRows = State(initialValue: [])
            case .fact:
                self._factAnswer = State(initialValue: "")
                self._factDetail = State(initialValue: "")
            }
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                cardFrontSection
                cardImageSection
                imagePromptSection
                cardBackFieldsSection
            }
            .navigationTitle("Edit \(card.cardType.displayName)")
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
    
    // MARK: - Card Front Section
    
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
    
    // MARK: - Card Image Section
    
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
    
    // MARK: - Image Prompt Section
    
    private var imagePromptSection: some View {
        Section("Image Prompt") {
            VStack(alignment: .leading, spacing: 12) {
                TextEditor(text: $imagePrompt)
                    .frame(minHeight: 60)
                    .onChange(of: imagePrompt) { _, newValue in
                        // Reset image generation failure counter when prompt is edited
                        if newValue != originalImagePrompt {
                            card.resetImageGenerationFailures()
                        }
                    }
                
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
    
    // MARK: - Card Back Fields Section
    
    @ViewBuilder
    private var cardBackFieldsSection: some View {
        switch card.cardType {
        case .vocabulary:
            vocabularyFieldsSection
        case .conjugation:
            conjugationFieldsSection
        case .fact:
            factFieldsSection
        }
    }
    
    // MARK: - Vocabulary Fields
    
    private var vocabularyFieldsSection: some View {
        Group {
            Section("Meaning") {
                TextEditor(text: $vocabularyMeaning)
                    .frame(minHeight: 60)
            }
            
            Section("Additional Detail (Optional)") {
                TextEditor(text: $vocabularyDetail)
                    .frame(minHeight: 40)
            }
        }
    }
    
    // MARK: - Conjugation Fields
    
    private var conjugationFieldsSection: some View {
        Group {
            Section("English Meaning") {
                TextEditor(text: $conjugationMeaning)
                    .frame(minHeight: 60)
            }
            
            Section("Conjugations") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(conjugationRows.indices, id: \.self) { rowIndex in
                        conjugationRowView(rowIndex: rowIndex)
                    }
                    
                    HStack {
                        Button("Add Conjugation") {
                            conjugationRows.append(["", ""])
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                        
                        Spacer()
                        
                        if !conjugationRows.isEmpty {
                            Button("Remove Last") {
                                conjugationRows.removeLast()
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                        }
                    }
                }
            }
        }
    }
    
    private func conjugationRowView(rowIndex: Int) -> some View {
        HStack(spacing: 8) {
            TextField("Pronoun", text: Binding(
                get: { 
                    conjugationRows[rowIndex].indices.contains(0) ? conjugationRows[rowIndex][0] : ""
                },
                set: { newValue in
                    if conjugationRows[rowIndex].indices.contains(0) {
                        conjugationRows[rowIndex][0] = newValue
                    }
                }
            ))
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .frame(maxWidth: 100)
            
            TextField("Conjugated Form", text: Binding(
                get: { 
                    conjugationRows[rowIndex].indices.contains(1) ? conjugationRows[rowIndex][1] : ""
                },
                set: { newValue in
                    if conjugationRows[rowIndex].indices.contains(1) {
                        conjugationRows[rowIndex][1] = newValue
                    }
                }
            ))
            .textFieldStyle(RoundedBorderTextFieldStyle())
            
            Button(action: {
                conjugationRows.remove(at: rowIndex)
            }) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.red)
            }
        }
    }
    
    // MARK: - Fact Fields
    
    private var factFieldsSection: some View {
        Group {
            Section("Answer") {
                TextEditor(text: $factAnswer)
                    .frame(minHeight: 80)
            }
            
            Section("Additional Detail (Optional)") {
                TextEditor(text: $factDetail)
                    .frame(minHeight: 40)
            }
        }
    }
    
    // MARK: - Toolbar
    
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
                .disabled(!isValidForSave)
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
                .disabled(!isValidForSave)
            }
            #endif
        }
    }
    
    // MARK: - Validation
    
    private var isValidForSave: Bool {
        let frontValid = !front.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        
        switch card.cardType {
        case .vocabulary:
            return frontValid && !vocabularyMeaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .conjugation:
            return frontValid && !conjugationMeaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .fact:
            return frontValid && !factAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    
    // MARK: - Helper Methods
    
    private func removeCardImage() {
        imageRemoved = true
        card.objectWillChange.send()
        card.clearCustomImage()
        
        do {
            try viewContext.save()
            viewContext.refreshAllObjects()
            viewContext.refresh(card, mergeChanges: true)
            viewRefreshTrigger = UUID()
            print("🗑️ Removed custom image from card: \(card.front)")
        } catch {
            print("❌ Failed to save after removing card image: \(error)")
            alertMessage = "Failed to remove image: \(error.localizedDescription)"
            showingAlert = true
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
                    // Parse the AI-generated content and populate fields
                    parseGeneratedContent(suggestion.formattedBack)
                    
                    // Update image prompt if the AI generated one
                    if let newImagePrompt = suggestion.imagePrompt, !newImagePrompt.isEmpty {
                        imagePrompt = newImagePrompt
                        print("💾 Updated image prompt from AI: '\(newImagePrompt)'")
                    }
                }
            } catch {
                await MainActor.run {
                    print("❌ Card generation failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func parseGeneratedContent(_ content: String) {
        // Try to parse as JSON first, fallback to simple text assignment
        if let data = content.data(using: .utf8) {
            do {
                let decoder = JSONDecoder()
                switch card.cardType {
                case .vocabulary:
                    let vocabContent = try decoder.decode(VocabularyContent.self, from: data)
                    vocabularyMeaning = vocabContent.meaning
                    vocabularyDetail = vocabContent.detail ?? ""
                case .conjugation:
                    let conjugContent = try decoder.decode(ConjugationContent.self, from: data)
                    conjugationMeaning = conjugContent.meaning
                    conjugationRows = conjugContent.conjugations
                case .fact:
                    let factContent = try decoder.decode(FactContent.self, from: data)
                    factAnswer = factContent.answer
                    factDetail = factContent.detail ?? ""
                }
            } catch {
                // Fallback to simple assignment
                switch card.cardType {
                case .vocabulary:
                    vocabularyMeaning = content
                case .conjugation:
                    conjugationMeaning = content
                case .fact:
                    factAnswer = content
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
        
        // Create structured content based on card type
        let structuredContent: any CardContent
        switch card.cardType {
        case .vocabulary:
            structuredContent = VocabularyContent(
                meaning: vocabularyMeaning.trimmingCharacters(in: .whitespacesAndNewlines),
                detail: vocabularyDetail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : vocabularyDetail.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        case .conjugation:
            // Filter out empty conjugation rows
            let validConjugations = conjugationRows.filter { row in
                row.count >= 2 && !row[0].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !row[1].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }.map { row in
                [row[0].trimmingCharacters(in: .whitespacesAndNewlines), row[1].trimmingCharacters(in: .whitespacesAndNewlines)]
            }
            
            structuredContent = ConjugationContent(
                meaning: conjugationMeaning.trimmingCharacters(in: .whitespacesAndNewlines),
                conjugations: validConjugations
            )
        case .fact:
            structuredContent = FactContent(
                answer: factAnswer.trimmingCharacters(in: .whitespacesAndNewlines),
                detail: factDetail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : factDetail.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        
        // Set the structured content
        card.setStructuredContent(structuredContent)
        
        // Clear legacy back field
        card.back = ""
        
        // Save the image prompt (empty string becomes nil)
        let trimmedImagePrompt = imagePrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        card.imagePrompt = trimmedImagePrompt.isEmpty ? nil : trimmedImagePrompt
        
        do {
            try viewContext.save()
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
    
    return FieldLevelCardEditView(card: card, deck: deck)
        .environment(\.managedObjectContext, context)
}