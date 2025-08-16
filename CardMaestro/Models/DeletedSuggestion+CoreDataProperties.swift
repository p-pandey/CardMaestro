import Foundation
import CoreData

extension DeletedSuggestion {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DeletedSuggestion> {
        return NSFetchRequest<DeletedSuggestion>(entityName: "DeletedSuggestion")
    }

    @NSManaged public var id: UUID
    @NSManaged public var front: String
    @NSManaged public var cardType: String
    @NSManaged public var deletedAt: Date
    @NSManaged public var deck: Deck

}