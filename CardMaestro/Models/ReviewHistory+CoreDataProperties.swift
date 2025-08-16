import Foundation
import CoreData

extension ReviewHistory {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ReviewHistory> {
        return NSFetchRequest<ReviewHistory>(entityName: "ReviewHistory")
    }

    @NSManaged public var id: UUID
    @NSManaged public var reviewDate: Date
    @NSManaged public var ease: Int16
    @NSManaged public var timeSpent: Int32
    @NSManaged public var card: Card
    @NSManaged public var session: StudySession?

}