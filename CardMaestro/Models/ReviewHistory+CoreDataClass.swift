import Foundation
import CoreData

@objc(ReviewHistory)
public class ReviewHistory: NSManagedObject, Identifiable {
    var reviewEase: ReviewEase {
        get {
            return ReviewEase(rawValue: ease) ?? .good
        }
        set {
            ease = newValue.rawValue
        }
    }
}