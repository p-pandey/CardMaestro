import Foundation
import CoreData
import SwiftUI

@objc(Deck)
public class Deck: NSManagedObject, Identifiable {
    var cardArray: [Card] {
        let set = cards as? Set<Card> ?? []
        return set.filter { !$0.isDeleted }.sorted { $0.createdAt < $1.createdAt }
    }
    
    var activeCards: [Card] {
        return cardArray.filter { $0.state == .active }
    }
    
    var archivedCards: [Card] {
        return cardArray.filter { $0.state == .archived }.sorted { 
            ($0.archivedAt ?? Date.distantPast) > ($1.archivedAt ?? Date.distantPast)
        }
    }
    
    
    var dueCards: [Card] {
        return activeCards.filter { $0.isDue }
    }
    
    var newCards: [Card] {
        return activeCards.filter { $0.isNew }
    }
    
    var totalCards: Int {
        return activeCards.count
    }
    
    var dueCount: Int {
        return dueCards.count
    }
    
    var newCount: Int {
        return newCards.count
    }
    
    func hasDuplicateCard(front: String, type: CardType) -> Bool {
        let trimmedFront = front.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        // Check active cards to prevent duplicates based on front+type
        let allCards = activeCards
        return allCards.contains { 
            $0.front.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == trimmedFront && 
            $0.cardType == type
        }
    }
    
    func hasDuplicateCard(front: String, type: CardType, excluding: Card?) -> Bool {
        let trimmedFront = front.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let allCards = activeCards
        return allCards.contains { card in
            // Skip the card being edited
            if let excluding = excluding, card.objectID == excluding.objectID {
                return false
            }
            return card.front.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == trimmedFront && 
                   card.cardType == type
        }
    }
    
    
    var completionPercentage: Double {
        guard totalCards > 0 else { return 0.0 }
        let reviewedCards = activeCards.filter { !$0.isNew }.count
        let percentage = Double(reviewedCards) / Double(totalCards)
        return min(max(percentage, 0.0), 1.0) // Clamp between 0 and 1
    }
    
    // MARK: - Visual Properties
    
    /// Automatically determines deck color based on name and description
    var deckColor: Color {
        // Validate deck name to prevent issues
        guard !name.isEmpty else {
            print("⚠️ Deck has empty name, using fallback color")
            return .blue
        }
        
        let _ = (name + " " + (deckDescription ?? "")).lowercased()
        
        // Use color based on deck name hash for consistency
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .cyan, .indigo, .mint, .teal]
        
        // Ensure we have a valid name and colors array
        guard !name.isEmpty, !colors.isEmpty else {
            return .blue // Safe fallback
        }
        
        let hash = name.hashValue
        let index = abs(hash) % colors.count
        return colors[index]
    }
    
    /// Returns the custom generated icon if available, otherwise falls back to SF Symbol
    var deckIcon: String {
        // Check if we have a custom generated icon stored
        if hasCustomIcon {
            return "custom_generated"  // Placeholder - will be handled by the view
        }
        
        // Fall back to automatic SF Symbol selection
        return automaticSFSymbolIcon
    }
    
    /// Check if this deck has a custom generated icon
    var hasCustomIcon: Bool {
        return customIconData != nil
    }
    
    /// Custom icon as UIImage (if generated)
    var customIcon: UIImage? {
        guard let iconData = customIconData else { return nil }
        
        guard let image = UIImage(data: iconData) else {
            print("⚠️ Failed to decode custom icon data for deck: \(name)")
            return nil
        }
        
        // Validate that the image has valid dimensions
        let size = image.size
        guard size.width > 0 && size.height > 0 && 
              size.width.isFinite && size.height.isFinite &&
              !size.width.isNaN && !size.height.isNaN else {
            print("⚠️ Custom icon has invalid dimensions: \(size) for deck: \(name)")
            return nil
        }
        
        return image
    }
    
    /// Store custom generated icon
    func setCustomIcon(_ image: UIImage) {
        // Validate image dimensions before storing
        let size = image.size
        guard size.width > 0 && size.height > 0 && 
              size.width.isFinite && size.height.isFinite &&
              !size.width.isNaN && !size.height.isNaN else {
            print("⚠️ Refusing to store custom icon with invalid dimensions: \(size) for deck: \(name)")
            return
        }
        
        // Validate that we can encode the image
        guard let pngData = image.pngData(), !pngData.isEmpty else {
            print("⚠️ Failed to encode custom icon to PNG data for deck: \(name)")
            return
        }
        
        customIconData = pngData
        print("✅ Successfully stored custom icon (\(pngData.count) bytes) for deck: \(name)")
    }
    
    /// Remove custom icon and fall back to SF Symbol
    func clearCustomIcon() {
        customIconData = nil
    }
    
    /// Automatically determines SF Symbol icon based on name and description
    private var automaticSFSymbolIcon: String {
        let _ = (name + " " + (deckDescription ?? "")).lowercased()
        
        // Always use default icon - no subject-specific assumptions
        return "rectangle.stack.fill"
    }
    
    /// Sets number of suggestions to 0 if user wants to disable automatic suggestions
    func setQueuedSuggestions(_ count: Int32) {
        queuedSuggestions = max(0, count) // Allow 0 or greater
    }
    
    // MARK: - Card State Lists
    
    /// All suggestion cards for this deck (AI-generated, ready for review)
    var suggestionCards: [Card] {
        return cardArray.filter { $0.state == .suggestion }.sorted { $0.createdAt < $1.createdAt }
    }
    
    /// Suggestion cards awaiting image generation
    var pendingSuggestionCards: [Card] {
        return cardArray.filter { $0.state == .suggestionPending }.sorted { $0.createdAt < $1.createdAt }
    }
    
    /// All suggestion-related cards (both ready and pending)
    var allSuggestionCards: [Card] {
        return cardArray.filter { $0.state == .suggestion || $0.state == .suggestionPending }.sorted { $0.createdAt < $1.createdAt }
    }
    
    /// Cards ready for user review (same as suggestionCards for backwards compatibility)
    var visibleSuggestions: [Card] {
        return suggestionCards
    }
    
    /// Cards awaiting image generation (same as pendingSuggestionCards for backwards compatibility)
    var invisibleSuggestions: [Card] {
        return pendingSuggestionCards
    }
    
    /// Deleted suggestion records
    var deletedSuggestionArray: [DeletedSuggestion] {
        let set = deletedSuggestions as? Set<DeletedSuggestion> ?? []
        return set.filter { !$0.isDeleted }.sorted { $0.deletedAt > $1.deletedAt }
    }
    
    /// Check if a suggestion was already deleted/rejected
    func wasSuggestionDeleted(front: String, cardType: String) -> Bool {
        return deletedSuggestionArray.contains { $0.matches(front: front, cardType: cardType) }
    }
    
    /// Mark a suggestion as deleted/rejected
    func markSuggestionDeleted(front: String, cardType: String, context: NSManagedObjectContext) {
        let deletedSuggestion = DeletedSuggestion(context: context)
        deletedSuggestion.id = UUID()
        deletedSuggestion.front = front
        deletedSuggestion.cardType = cardType
        deletedSuggestion.deletedAt = Date()
        deletedSuggestion.deck = self
        addToDeletedSuggestions(deletedSuggestion)
    }
}