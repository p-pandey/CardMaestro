import SwiftUI
import CoreData

struct DeckCreationView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var description = ""
    @State private var queuedSuggestions = 50
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isCreating = false
    @StateObject private var backgroundImageService = BackgroundImageGenerationService.shared
    
    var body: some View {
        NavigationView {
            Form {
                Section("Deck Information") {
                    TextField("Deck Name", text: $name)
                    TextField("Description (Optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Automatic Suggestions")
                                .font(.body)
                            Text("Number of AI-generated card suggestions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Stepper(value: $queuedSuggestions, in: 0...200, step: 10) {
                            Text("\(queuedSuggestions)")
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    if queuedSuggestions == 0 {
                        Text("Set to 0 to disable automatic suggestions")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                } header: {
                    Text("AI Settings")
                }
            }
            .navigationTitle("New Deck")
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
                    Button(isCreating ? "Creating..." : "Create") {
                        saveDeck()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(isCreating ? "Creating..." : "Create") {
                        saveDeck()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
                }
                #endif
            }
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func saveDeck() {
        isCreating = true
        
        let deckName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let deckDesc = description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Create deck immediately without blocking on image generation
        let newDeck = Deck(context: viewContext)
        newDeck.id = UUID()
        newDeck.name = deckName
        newDeck.deckDescription = deckDesc
        newDeck.createdAt = Date()
        newDeck.queuedSuggestions = Int32(queuedSuggestions)
        
        do {
            try viewContext.save()
            
            // Start background image generation with placeholder
            backgroundImageService.setPlaceholderAndQueue(for: newDeck, priority: .user_requested)
            
            // Play deck creation sound
            SoundService.shared.playDeckCreated()
            
            print("✅ Created deck '\(deckName)' with background image generation queued")
            
            isCreating = false
            dismiss()
        } catch {
            alertMessage = "Failed to create deck: \(error.localizedDescription)"
            showingAlert = true
            isCreating = false
        }
    }
}

#Preview {
    DeckCreationView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}