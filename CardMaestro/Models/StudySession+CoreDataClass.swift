import Foundation
import CoreData

@objc(StudySession)
public class StudySession: NSManagedObject, Identifiable {
    var duration: TimeInterval {
        guard let endTime = endTime else {
            return Date().timeIntervalSince(startTime)
        }
        return endTime.timeIntervalSince(startTime)
    }
    
    var reviewArray: [ReviewHistory] {
        let set = reviews as? Set<ReviewHistory> ?? []
        return set.sorted { $0.reviewDate < $1.reviewDate }
    }
}