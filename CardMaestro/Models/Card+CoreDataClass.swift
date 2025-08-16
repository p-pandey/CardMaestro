import Foundation
import CoreData
import UIKit

/// Card state for organizing cards into different lists
enum CardState: String, CaseIterable {
    case active = "active"              // Normal cards ready for study
    case suggestion = "suggestion"      // AI-generated cards ready for user review
    case suggestionPending = "suggestionPending"  // AI-generated cards awaiting image generation
    case archived = "archived"          // Cards set aside by user (same as isArchived)
    
    var displayName: String {
        switch self {
        case .active: return "Active"
        case .suggestion: return "Suggested"
        case .suggestionPending: return "Pending"
        case .archived: return "Archived"
        }
    }
}

@objc(Card)
public class Card: NSManagedObject, Identifiable {
    
    /// Card type for this card
    var cardType: CardType {
        get {
            return CardType.from(string: self.cardTypeRaw)
        }
        set {
            self.cardTypeRaw = newValue.rawValue
        }
    }
    
    /// Current state of the card
    var state: CardState {
        get {
            return CardState(rawValue: cardState) ?? .active
        }
        set {
            cardState = newValue.rawValue
            // Keep isArchived in sync for backwards compatibility
            if newValue == .archived {
                isArchived = true
                if archivedAt == nil {
                    archivedAt = Date()
                }
            } else {
                isArchived = false
                archivedAt = nil
            }
        }
    }
    
    /// Sets the card type to default if not already set
    func setDefaultCardTypeIfNeeded() {
        if cardTypeRaw == nil || cardTypeRaw!.isEmpty {
            cardType = .vocabulary // Default type
        }
    }
    var isDue: Bool {
        guard let dueDate = dueDate else { return true }
        return dueDate <= Date()
    }
    
    var isNew: Bool {
        return repetitions == 0
    }
    
    var reviewHistoryArray: [ReviewHistory] {
        let set = reviewHistory as? Set<ReviewHistory> ?? []
        return set.sorted { $0.reviewDate < $1.reviewDate }
    }
    
    /// Set archived status using Core Data properties
    func setArchived(_ archived: Bool, at date: Date? = nil) {
        isArchived = archived
        archivedAt = archived ? (date ?? Date()) : nil
    }
    
    
    
    func scheduleReview(ease: ReviewEase) {
        let now = Date()
        lastReviewedAt = now
        reviewCount += 1
        
        // For new cards (repetitions == 0), ensure we move them out of new status
        let wasNew = repetitions == 0
        
        switch ease {
        case .again:
            if wasNew {
                // New card failed - schedule for 10 minutes
                interval = 0
                repetitions = 0
                dueDate = Calendar.current.date(byAdding: .minute, value: 10, to: now)
            } else {
                // Review card failed - back to beginning
                repetitions = 0
                interval = 1
                easeFactor = max(1.3, easeFactor - 0.2)
                dueDate = Calendar.current.date(byAdding: .day, value: 1, to: now)
            }
        case .hard:
            if wasNew {
                // New card was hard - schedule for 1 day
                interval = 1
                repetitions = 1
                dueDate = Calendar.current.date(byAdding: .day, value: 1, to: now)
            } else {
                repetitions = max(1, repetitions)
                interval = max(1, Int32(Double(interval) * 1.2))
                dueDate = Calendar.current.date(byAdding: .day, value: Int(interval), to: now)
            }
            easeFactor = max(1.3, easeFactor - 0.15)
        case .good:
            if repetitions == 0 {
                interval = 1
                repetitions = 1
                dueDate = Calendar.current.date(byAdding: .day, value: 1, to: now)
            } else if repetitions == 1 {
                interval = 6
                repetitions = 2
                dueDate = Calendar.current.date(byAdding: .day, value: 6, to: now)
            } else {
                interval = Int32(Double(interval) * Double(easeFactor))
                repetitions += 1
                dueDate = Calendar.current.date(byAdding: .day, value: Int(interval), to: now)
            }
        case .easy:
            if repetitions == 0 {
                interval = 4
                repetitions = 1
                dueDate = Calendar.current.date(byAdding: .day, value: 4, to: now)
            } else {
                interval = Int32(Double(interval) * Double(easeFactor) * 1.3)
                repetitions += 1
                dueDate = Calendar.current.date(byAdding: .day, value: Int(interval), to: now)
            }
            easeFactor = min(2.5, easeFactor + 0.15)
        }
    }
    
    // MARK: - Custom Image Handling
    
    /// Custom image for this card
    var customImage: UIImage? {
        guard let imageData = customImageData else { return nil }
        return UIImage(data: imageData)
    }
    
    /// Sets a custom image for this card
    func setCustomImage(_ image: UIImage) {
        if let imageData = image.jpegData(compressionQuality: 0.8) {
            customImageData = imageData
            print("📸 Set custom image for card: \(front) (size: \(imageData.count) bytes)")
        } else {
            print("❌ Failed to convert image to data for card: \(front)")
        }
    }
    
    /// Clears the custom image for this card
    func clearCustomImage() {
        customImageData = nil
        print("🗑️ Cleared custom image for card: \(front)")
    }
    
    /// Whether this card has a custom image
    var hasCustomImage: Bool {
        return customImageData != nil
    }
    
    /// Whether this card needs an image (has no custom image and isn't a placeholder)
    var needsImage: Bool {
        return customImageData == nil
    }
    
    // MARK: - State Management
    
    /// Move card to suggestion state (AI-generated, ready for review)
    func makeSuggestion(context: String? = nil, category: String? = nil) {
        state = .suggestion
        suggestionContext = context
        suggestionCategory = category
        // Reset study data for suggestions
        easeFactor = 2.5
        interval = 0
        repetitions = 0
        reviewCount = 0
        lastReviewedAt = nil
        dueDate = nil
    }
    
    /// Move card to suggestion pending state (AI-generated, awaiting image)
    func makeSuggestionPending(context: String? = nil, category: String? = nil) {
        state = .suggestionPending
        suggestionContext = context
        suggestionCategory = category
        // Reset study data for suggestions
        easeFactor = 2.5
        interval = 0
        repetitions = 0
        reviewCount = 0
        lastReviewedAt = nil
        dueDate = nil
    }
    
    /// Accept suggestion and make it an active card
    func acceptSuggestion() {
        state = .active
        suggestionContext = nil
        suggestionCategory = nil
        // Keep existing study data or defaults
    }
    
    /// Archive this card
    func archive() {
        state = .archived
    }
    
    /// Unarchive this card
    func unarchive() {
        state = .active
    }
    
    // MARK: - JSON Content Management
    
    /// Gets the structured content for this card based on its type
    var structuredContent: (any CardContent)? {
        guard let jsonContent = jsonContent else { return nil }
        
        do {
            return try CardContentWrapper.decode(jsonString: jsonContent, cardType: cardType)
        } catch {
            print("❌ Failed to decode card content: \(error)")
            return nil
        }
    }
    
    /// Sets the structured content for this card
    func setStructuredContent<T: CardContent>(_ content: T) {
        do {
            jsonContent = try CardContentWrapper.encode(content)
        } catch {
            print("❌ Failed to encode card content: \(error)")
        }
    }
    
    /// Gets the vocabulary content if this is a vocabulary card
    var vocabularyContent: VocabularyContent? {
        guard cardType == .vocabulary else { return nil }
        return structuredContent as? VocabularyContent
    }
    
    /// Gets the conjugation content if this is a conjugation card
    var conjugationContent: ConjugationContent? {
        guard cardType == .conjugation else { return nil }
        return structuredContent as? ConjugationContent
    }
    
    /// Gets the fact content if this is a fact card
    var factContent: FactContent? {
        guard cardType == .fact else { return nil }
        return structuredContent as? FactContent
    }
    
    // MARK: - Image Generation Failure Tracking
    
    /// Records an image generation failure
    func recordImageGenerationFailure() {
        imageGenerationFailureCount += 1
        lastImageGenerationFailure = Date()
        print("📉 Image generation failure recorded for card '\(front)': \(imageGenerationFailureCount) failures")
        
        // Auto-archive logic
        if shouldAutoArchiveAfterFailures() {
            print("🗄️ Auto-archiving card '\(front)' after \(imageGenerationFailureCount) image generation failures")
            archive()
        }
    }
    
    /// Resets the image generation failure counter (called when image prompt is edited)
    func resetImageGenerationFailures() {
        if imageGenerationFailureCount > 0 {
            print("🔄 Resetting image generation failure count for card '\(front)' (was \(imageGenerationFailureCount))")
            imageGenerationFailureCount = 0
            lastImageGenerationFailure = nil
        }
    }
    
    /// Whether this card should be auto-archived after image generation failures
    private func shouldAutoArchiveAfterFailures() -> Bool {
        guard imageGenerationFailureCount >= 3 else { return false }
        
        // Auto-archive suggestion and suggestionPending cards after 3 failures
        return state == .suggestion || state == .suggestionPending
    }
    
    /// Whether image generation should be attempted for this card
    var shouldAttemptImageGeneration: Bool {
        // Don't attempt if already archived
        if state == .archived { return false }
        
        // Don't attempt if we've had 3+ failures on active cards
        if state == .active && imageGenerationFailureCount >= 3 { return false }
        
        // For suggestion cards, they get auto-archived after 3 failures
        return true
    }
    
}

enum ReviewEase: Int16, CaseIterable {
    case again = 1
    case hard = 2
    case good = 3
    case easy = 4
    
    var title: String {
        switch self {
        case .again: return "Again"
        case .hard: return "Hard"
        case .good: return "Good"
        case .easy: return "Easy"
        }
    }
    
    var color: String {
        switch self {
        case .again: return "red"
        case .hard: return "orange"
        case .good: return "green"
        case .easy: return "blue"
        }
    }
}