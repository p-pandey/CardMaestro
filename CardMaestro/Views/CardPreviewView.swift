import SwiftUI
import CoreData

struct CardPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    @ObservedObject var card: Card
    let deck: Deck
    
    @State private var showingBack = false
    @State private var showingEdit = false
    @State private var flipDegrees = 0.0
    @State private var viewRefreshTrigger = UUID()
    
    var body: some View {
NavigationView {
ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 16) {
                    // Card display area
                    cardDisplayArea
                        .padding(.top, 8)
                    
                    // Card info section
                    cardInfoSection
                        .padding(.horizontal, CardConstants.Dimensions.horizontalPadding)
                        .padding(.bottom, 16)
                }
            }
            .navigationTitle("Card Preview")
            .navigationBarTitleDisplayMode(.inline)
.toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        showingEdit = true
                    }
                    .fontWeight(.medium)
                }
            }
        }
        .sheet(isPresented: $showingEdit, onDismiss: {
            // Force comprehensive refresh when returning from edit view
            refreshCardData()
        }) {
FieldLevelCardEditView(card: card, deck: deck)
        }
    }
    
    private var cardDisplayArea: some View {
        VStack(spacing: 16) {
            // Debug info - remove if working
            if card.front.isEmpty && (card.jsonContent?.isEmpty ?? true) {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title)
                        .foregroundColor(.orange)
                    Text("Card data appears to be empty")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                // Use our own simplified card display instead of CardView to avoid dependencies
                simplifiedCardView
            }
        }
    }
    
    private var simplifiedCardView: some View {
        ZStack {
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
            
            // Back of card
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
            .id(viewRefreshTrigger) // Force view recreation when trigger changes
        }
        .frame(minHeight: CardConstants.Dimensions.totalContainerHeight)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, CardConstants.Dimensions.horizontalPadding)
        .onTapGesture {
            SoundService.shared.playCardFlip()
            withAnimation(.easeInOut(duration: 0.6)) {
                showingBack.toggle()
            }
        }
        .onChange(of: showingBack) { _, newValue in
            withAnimation(.easeInOut(duration: 0.6)) {
                flipDegrees = newValue ? 180 : 0
            }
        }
    }
    
    private var cardInfoSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Status")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        if card.isNew {
                            StatusBadge(text: "New", color: .green)
                        } else if card.isDue {
                            StatusBadge(text: "Due", color: .red)
                        } else if let dueDate = card.dueDate {
                            StatusBadge(text: formatDueDate(dueDate), color: .blue)
                        }
                        
                        Text("Reviewed ×\(card.reviewCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Progress")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 3) {
                        ForEach(0..<5, id: \.self) { index in
                            Circle()
                                .fill(index < Int(card.repetitions) ? Color.blue : Color.gray.opacity(0.3))
                                .frame(width: 6, height: 6)
                        }
                    }
                }
            }
            
            // Card type info
            HStack {
                Text("Type:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Image(systemName: card.cardType.icon)
                        .font(.caption)
                        .foregroundColor(card.cardType.color)
                    
                    Text(card.cardType.displayName)
                        .font(.caption)
                        .foregroundColor(card.cardType.color)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(card.cardType.color.opacity(0.1))
                )
            }
            
            if let lastReview = card.lastReviewedAt {
                HStack {
                    Text("Last reviewed:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(formatDate(lastReview))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Text("Created:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(formatDate(card.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
    
    private func formatDueDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func refreshCardData() {
        // 1. Force the observed object to notify of changes
        card.objectWillChange.send()
        
        // 2. Force refresh the entire managed object context
        viewContext.refreshAllObjects()
        
        // 3. Force refresh the specific card object
        viewContext.refresh(card, mergeChanges: true)
        
        // 4. Trigger view recreation by changing the UUID
        viewRefreshTrigger = UUID()
        
print("🔄 Refreshed card preview data for card: \(card.front)")
    }
}

