import Foundation
import CoreData

extension Deck {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Deck> {
        return NSFetchRequest<Deck>(entityName: "Deck")
    }

    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var deckDescription: String?
    @NSManaged public var createdAt: Date
    @NSManaged public var customIconData: Data?
    @NSManaged public var queuedSuggestions: Int32
    @NSManaged public var cards: NSSet?
    @NSManaged public var tags: NSSet?
    @NSManaged public var deletedSuggestions: NSSet?

}

// MARK: Generated accessors for cards
extension Deck {

    @objc(addCardsObject:)
    @NSManaged public func addToCards(_ value: Card)

    @objc(removeCardsObject:)
    @NSManaged public func removeFromCards(_ value: Card)

    @objc(addCards:)
    @NSManaged public func addToCards(_ values: NSSet)

    @objc(removeCards:)
    @NSManaged public func removeFromCards(_ values: NSSet)

}

// MARK: Generated accessors for tags
extension Deck {

    @objc(addTagsObject:)
    @NSManaged public func addToTags(_ value: Tag)

    @objc(removeTagsObject:)
    @NSManaged public func removeFromTags(_ value: Tag)

    @objc(addTags:)
    @NSManaged public func addToTags(_ values: NSSet)

    @objc(removeTags:)
    @NSManaged public func removeFromTags(_ values: NSSet)

}


// MARK: Generated accessors for deletedSuggestions
extension Deck {

    @objc(addDeletedSuggestionsObject:)
    @NSManaged public func addToDeletedSuggestions(_ value: DeletedSuggestion)

    @objc(removeDeletedSuggestionsObject:)
    @NSManaged public func removeFromDeletedSuggestions(_ value: DeletedSuggestion)

    @objc(addDeletedSuggestions:)
    @NSManaged public func addToDeletedSuggestions(_ values: NSSet)

    @objc(removeDeletedSuggestions:)
    @NSManaged public func removeFromDeletedSuggestions(_ values: NSSet)

}