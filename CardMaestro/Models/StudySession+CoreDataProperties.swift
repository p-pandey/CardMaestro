import Foundation
import CoreData

extension StudySession {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<StudySession> {
        return NSFetchRequest<StudySession>(entityName: "StudySession")
    }

    @NSManaged public var id: UUID
    @NSManaged public var startTime: Date
    @NSManaged public var endTime: Date?
    @NSManaged public var cardsReviewed: Int32
    @NSManaged public var reviews: NSSet?

}

// MARK: Generated accessors for reviews
extension StudySession {

    @objc(addReviewsObject:)
    @NSManaged public func addToReviews(_ value: ReviewHistory)

    @objc(removeReviewsObject:)
    @NSManaged public func removeFromReviews(_ value: ReviewHistory)

    @objc(addReviews:)
    @NSManaged public func addToReviews(_ values: NSSet)

    @objc(removeReviews:)
    @NSManaged public func removeFromReviews(_ values: NSSet)

}