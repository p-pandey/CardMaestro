import Foundation
import CoreData

extension SuggestionCard {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SuggestionCard> {
        return NSFetchRequest<SuggestionCard>(entityName: "SuggestionCard")
    }

    @NSManaged public var id: UUID
    @NSManaged public var front: String
    @NSManaged public var back: String
    @NSManaged public var cardTypeRaw: String
    @NSManaged public var imagePrompt: String?
    @NSManaged public var context: String
    @NSManaged public var category: String
    @NSManaged public var createdAt: Date
    @NSManaged public var isVisible: Bool
    @NSManaged public var customImageData: Data?
    @NSManaged public var deck: Deck

}