import Foundation
import CoreData

extension Card {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Card> {
        return NSFetchRequest<Card>(entityName: "Card")
    }

    @NSManaged public var id: UUID
    @NSManaged public var front: String
    @NSManaged public var back: String
    @NSManaged public var imagePrompt: String?
    @NSManaged public var cardTypeRaw: String?
    @NSManaged public var jsonContent: String?
    @NSManaged public var createdAt: Date
    @NSManaged public var customImageData: Data?
    @NSManaged public var lastReviewedAt: Date?
    @NSManaged public var dueDate: Date?
    @NSManaged public var interval: Int32
    @NSManaged public var repetitions: Int32
    @NSManaged public var easeFactor: Float
    @NSManaged public var reviewCount: Int32
    @NSManaged public var isArchived: Bool
    @NSManaged public var archivedAt: Date?
    @NSManaged public var cardState: String
    @NSManaged public var suggestionContext: String?
    @NSManaged public var suggestionCategory: String?
    @NSManaged public var deck: Deck
    @NSManaged public var reviewHistory: NSSet?

}

// MARK: Generated accessors for reviewHistory
extension Card {

    @objc(addReviewHistoryObject:)
    @NSManaged public func addToReviewHistory(_ value: ReviewHistory)

    @objc(removeReviewHistoryObject:)
    @NSManaged public func removeFromReviewHistory(_ value: ReviewHistory)

    @objc(addReviewHistory:)
    @NSManaged public func addToReviewHistory(_ values: NSSet)

    @objc(removeReviewHistory:)
    @NSManaged public func removeFromReviewHistory(_ values: NSSet)

}