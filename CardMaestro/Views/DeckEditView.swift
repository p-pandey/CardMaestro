import SwiftUI
import CoreData

struct DeckEditView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var deck: Deck
    
    @State private var deckName: String
    @State private var deckDescription: String
    @State private var queuedSuggestions: Int
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    init(deck: Deck) {
        self.deck = deck
        self._deckName = State(initialValue: deck.name)
        self._deckDescription = State(initialValue: deck.deckDescription ?? "")
        self._queuedSuggestions = State(initialValue: Int(deck.queuedSuggestions))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Deck Information") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Deck Name")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        TextField("Enter deck name", text: $deckName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        TextEditor(text: $deckDescription)
                            .frame(minHeight: 80)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                    }
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
                    } else {
                        Text("The app will automatically generate suggestions to maintain this target number.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("AI Settings")
                }
            }
            .navigationTitle("Edit Deck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveDeck()
                    }
                    .disabled(deckName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func saveDeck() {
        let trimmedName = deckName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            alertMessage = "Deck name cannot be empty."
            showingAlert = true
            return
        }
        
        // Update deck properties
        deck.name = trimmedName
        deck.deckDescription = deckDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : deckDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        deck.queuedSuggestions = Int32(queuedSuggestions)
        
        do {
            try viewContext.save()
            print("💾 Saved deck changes: '\(deck.name)' with \(deck.queuedSuggestions) target suggestions")
            
            // Trigger sweeper to adjust suggestions if target changed
            DispatchQueue.main.async {
                BackgroundImageGenerationService.shared.scanAndQueueMissingImages()
            }
            
            dismiss()
        } catch {
            alertMessage = "Failed to save deck: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let deck = Deck(context: context)
    deck.name = "Sample Deck"
    deck.deckDescription = "A sample deck for testing"
    deck.queuedSuggestions = 50
    deck.createdAt = Date()
    deck.id = UUID()
    
    return DeckEditView(deck: deck)
        .environment(\.managedObjectContext, context)
}