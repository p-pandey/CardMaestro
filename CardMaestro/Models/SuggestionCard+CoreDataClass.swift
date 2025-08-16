import Foundation
import CoreData
import UIKit

@objc(SuggestionCard)
public class SuggestionCard: NSManagedObject, Identifiable {
    
    /// Card type for this suggestion
    var cardType: CardType {
        get {
            return CardType.from(string: self.cardTypeRaw)
        }
        set {
            self.cardTypeRaw = newValue.rawValue
        }
    }
    
    /// Custom image for this suggestion
    var customImage: UIImage? {
        guard let imageData = customImageData else { return nil }
        return UIImage(data: imageData)
    }
    
    /// Sets a custom image for this suggestion
    func setCustomImage(_ image: UIImage) {
        if let imageData = image.jpegData(compressionQuality: 0.8) {
            customImageData = imageData
            print("📸 Set custom image for suggestion: \(front) (size: \(imageData.count) bytes)")
        } else {
            print("❌ Failed to convert image to data for suggestion: \(front)")
        }
    }
    
    /// Clears the custom image for this suggestion
    func clearCustomImage() {
        customImageData = nil
        print("🗑️ Cleared custom image for suggestion: \(front)")
    }
    
    /// Whether this suggestion has a custom image
    var hasCustomImage: Bool {
        return customImageData != nil
    }
    
    /// Whether this suggestion needs an image (has no custom image)
    var needsImage: Bool {
        return customImageData == nil
    }
    
    /// Convert to Card for deck inclusion
    func convertToCard(context: NSManagedObjectContext) -> Card {
        let card = Card(context: context)
        card.id = UUID()
        card.front = front
        card.back = back
        card.cardTypeRaw = cardTypeRaw
        card.imagePrompt = imagePrompt
        card.createdAt = Date()
        card.easeFactor = 2.5
        card.interval = 0
        card.repetitions = 0
        card.reviewCount = 0
        card.state = .active
        
        if let imageData = customImageData {
            card.customImageData = imageData
        }
        
        return card
    }
    
    /// Convert to temporary Card for UI display (not inserted into context)
    func convertToTemporaryCard() -> Card {
        let card = Card(entity: Card.entity(), insertInto: nil)
        card.id = id
        card.front = front
        card.back = back
        card.cardTypeRaw = cardTypeRaw
        card.imagePrompt = imagePrompt
        card.createdAt = createdAt
        card.easeFactor = 2.5
        card.interval = 0
        card.repetitions = 0
        card.reviewCount = 0
        card.state = .active
        
        if let imageData = customImageData {
            card.customImageData = imageData
        }
        
        return card
    }
}